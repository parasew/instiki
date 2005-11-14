# heavily based off difflib.py - see that file for documentation
# ported from Python by Bill Atkins

# This does not support all features offered by difflib; it 
# implements only the subset of features necessary
# to support a Ruby version of HTML Differ.  You're welcome to finish this off.

# By default, String#each iterates by line.  This isn't really appropriate
# for diff, so often a string will be split by // to get an array of one-
# character strings.

# Some methods in Diff are untested and are not guaranteed to work.  The
# methods in HTMLDiff and any methods it calls should work quite well.

# changes by DenisMertz
# * main change:
# ** get the tag soup away
#    the tag soup problem was first reported with <p> tags, but it appeared also with
#    <li>, <ul> etc... tags 
#   this version should mostly fix these problems
# ** added a Builder class to manage the creation of the final htmldiff
# * minor changes:
# ** use symbols instead of string to represent opcodes 
# ** small fix to html2list
#

module Enumerable
  def reduce(init)
    result = init
    each { |item| result = yield(result, item) }
    result
  end
end

class Object
  def nil_or_empty?
    nil? or empty?
  end
end

module Diff

  module Utilities
    def explode(sequence)
      sequence.is_a?(String) ? sequence.split(//) : sequence
    end

    def newline?(char)
      %W(\n \r).include? char
    end

    def tab?(char)
      "\t" == char
    end

    # XXX Could be more robust but unrecognized tags cause an infinite loop so
    # better to be permissive
    def open_tag?(char)
      char =~ /\A<[^>]+>/
    end

    # See comment for open_tag?
    def close_tag?(char)
      char =~ %r!\A</[^>]+>!
    end

    def end_of_tag?(char)
      char == '>'
    end

    def start_of_tag?(char)
      char == '<'
    end

    def html2list(x, use_brackets = false)
      mode = :char
      cur  = ''
      out  = []
      
      explode(x).each do |char|
        case mode
        when :tag
          if end_of_tag? char
            cur += use_brackets ? ']' : '>'
            out.push cur
            cur, mode  = '', :char
          else
            cur += char
          end
        when :char
          if start_of_tag? char
            out.push cur
            cur  = use_brackets ? '[' : '<'
            mode = :tag
          elsif /\s/.match char
            out.push cur + char
            cur = ''
          else
            cur += char
          end
        end
      end
      
      out.push(cur)
      out.delete '' 
      out.map {|elt| newline?(elt) ? elt : elt.chomp}
    end
  end

  class SequenceMatcher
    include Utilities

    def initialize(a = [''], b = [''], isjunk = nil, byline = false)
      a, b = explode(a), explode(b) unless byline 
      @isjunk = isjunk || Proc.new {}
      set_sequences a, b
    end

    def set_sequences(a, b)
      set_sequence_a a
      set_sequence_b b
    end

    def set_sequence_a(a)
      @a = a
      @matching_blocks = @opcodes = nil
    end

    def set_sequence_b(b)
      @b = b
      @matching_blocks = @opcodes = nil
      chain_b
    end

    def chain_b
      @fullbcount = nil
      @b2j     = {}
      pophash  = {}
      junkdict = {}
      
      @b.each_with_index do |elt, idx|
        if @b2j.has_key? elt
          indices = @b2j[elt]
          if @b.length >= 200 and indices.length * 100 > @b.length
            pophash[elt] = 1
            indices.clear
          else
            indices.push idx
          end
        else
          @b2j[elt] = [idx]
        end
      end
        
      pophash.each_key { |elt| @b2j.delete elt }
      
      unless @isjunk.nil?
        [pophash, @b2j].each do |d|
          d.each_key do |elt|
            if @isjunk.call(elt)
              junkdict[elt] = 1
              d.delete elt
            end
          end
        end
      end
      
      @isbjunk    = junkdict.method(:has_key?)
      @isbpopular = junkdict.method(:has_key?)
    end
    
    def find_longest_match(a_low, a_high, b_low, b_high)
      besti, bestj, bestsize = a_low, b_low, 0
      
      j2len = {}
      
      (a_low..a_high).step do |i|
        newj2len = {}
        (@b2j[@a[i]] || []).each do |j|
          next  if j < b_low
          break if j >= b_high
          
          k = newj2len[j] = (j2len[j - 1] || 0) + 1
          if k > bestsize
            besti, bestj, bestsize = i - k + 1, j - k + 1, k
          end
        end
        j2len = newj2len
      end
      
      while besti > a_low and bestj > b_low and not @isbjunk.call(@b[bestj - 1]) and @a[besti - 1] == @b[bestj - 1]
        besti, bestj, bestsize = besti - 1, bestj - 1, bestsize + 1
      end
      
      while besti + bestsize < a_high and bestj + bestsize < b_high and
          not @isbjunk.call(@b[bestj + bestsize]) and
          @a[besti + bestsize] == @b[bestj + bestsize]
        bestsize += 1
      end
      
      while besti > a_low and bestj > b_low and @isbjunk.call(@b[bestj - 1]) and @a[besti - 1] == @b[bestj - 1]
        besti, bestj, bestsize = besti - 1, bestj - 1, bestsize + 1
      end
      
      while besti + bestsize < a_high and bestj + bestsize < b_high and @isbjunk.call(@b[bestj+bestsize]) and
          @a[besti+bestsize] == @b[bestj+bestsize]
        bestsize += 1
      end
      
      [besti, bestj, bestsize]
    end
    
    def get_matching_blocks
      return @matching_blocks unless @matching_blocks.nil_or_empty?
      
      @matching_blocks = []
      size_of_a, size_of_b = @a.size, @b.size
      match_block_helper(0, size_of_a, 0, size_of_b, @matching_blocks)
      @matching_blocks.push [size_of_a, size_of_b, 0]
    end
    
    def match_block_helper(a_low, a_high, b_low, b_high, answer)
      i, j, k = x = find_longest_match(a_low, a_high, b_low, b_high)
      unless k.zero?
        match_block_helper(a_low, i, b_low, j, answer) if a_low < i and b_low < j
        answer.push x
        if i + k < a_high and j + k < b_high
          match_block_helper(i + k, a_high, j + k, b_high, answer)
        end
      end
    end
    
    def get_opcodes
      return @opcodes unless @opcodes.nil_or_empty?

      i = j = 0
      @opcodes = answer = []
      get_matching_blocks.each do |ai, bj, size|
        tag = if i < ai and j < bj
                :replace
              elsif i < ai
                :delete
              elsif j < bj 
                :insert
              end

        answer.push [tag, i, ai, j, bj] if tag
        i, j = ai + size, bj + size
        answer.push [:equal, ai, i, bj, j] unless size.zero?
      end
      answer
    end

    # XXX: untested
    def get_grouped_opcodes(n = 3)
      codes = get_opcodes
      if codes.first.first == :equal
        tag, i1, i2, j1, j2 = codes.first
        codes[0] = tag, [i1, i2 - n].max, i2, [j1, j2-n].max, j2
      end
      
      if codes.last.first == :equal
        tag, i1, i2, j1, j2 = codes.last
        codes[-1] = tag, i1, min(i2, i1+n), j1, min(j2, j1+n)
      end

      nn = n + n
      group = []
      codes.each do |tag, i1, i2, j1, j2|
        if tag == :equal and i2 - i1 > nn
          group.push [tag, i1, [i2, i1 + n].min, j1, [j2, j1 + n].min]
          yield group
          group = []
          i1, j1 = [i1, i2-n].max, [j1, j2-n].max
          group.push [tag, i1, i2, j1 ,j2]
        end
      end
      yield group if group and group.size != 1 and group.first.first == :equal
    end

    def ratio
      matches = get_matching_blocks.reduce(0) do |sum, triple|
        sum + triple.last
      end
      Diff.calculate_ratio(matches, @a.size + @b.size)
    end

    def quick_ratio
      if @fullbcount.nil_or_empty?
        @fullbcount = {}
        @b.each do |elt|
          @fullbcount[elt] = (@fullbcount[elt] || 0) + 1
        end
      end
      
      avail   = {}
      matches = 0
      @a.each do |elt|
        numb       = avail.has_key?(elt) ? avail[elt] : (@fullbcount[elt] || 0)
        avail[elt] = numb - 1
        matches   += 1 if numb > 0
      end
      Diff.calculate_ratio matches, @a.size + @b.size
    end

    def real_quick_ratio
      size_of_a, size_of_b = @a.size, @b.size
      Diff.calculate_ratio([size_of_a, size_of_b].min, size_of_a + size_of_b)
    end

    protected :chain_b, :match_block_helper
  end # end class SequenceMatcher

  class << self
    def calculate_ratio(matches, length)
      return 1.0 if length.zero?
      2.0 * matches / length
    end

    # XXX: untested
    def get_close_matches(word, possibilities, n = 3, cutoff = 0.6)
      raise "n must be > 0: #{n}" unless n > 0
      raise "cutoff must be in (0.0..1.0): #{cutoff}" unless cutoff.between 0.0..1.0

      result = []
      sequence_matcher = Diff::SequenceMatcher.new
      sequence_matcher.set_sequence_b word
      possibilities.each do |possibility|
        sequence_matcher.set_sequence_a possibility
        if sequence_matcher.real_quick_ratio >= cutoff and
           sequence_matcher.quick_ratio >= cutoff      and
           sequence_matcher.ratio >= cutoff
          result.push [sequence_matcher.ratio, possibility]
        end
      end
      
      unless result.nil_or_empty?
        result.sort
        result.reverse!
        result = result[-n..-1]
      end
      result.map {|score, x| x }
    end

    def count_leading(line, ch)
      count, size = 0, line.size
      count += 1 while count < size and line[count].chr == ch
      count
    end
  end
end

module HTMLDiff
  include Diff
  class Builder
    VALID_METHODS = [:replace, :insert, :delete, :equal]
    def initialize(a, b)
      @a, @b   = a, b
      @content = []
    end

    def do_op(opcode)
      @opcode = opcode
      op      = @opcode.first
      raise NameError, "Invalid opcode '#{op}'" unless VALID_METHODS.include? op
      send op
    end

    def result
      @content.join
    end

    # These methods have to be called via do_op(opcode) so that @opcode is set properly
    private

      def replace
        delete('diffmod')
        insert('diffmod')
      end
      
      def insert(tagclass = 'diffins')
        op_helper('ins', tagclass, @b[@opcode[3]...@opcode[4]])
      end
      
      def delete(tagclass = 'diffdel')
         op_helper('del', tagclass, @a[@opcode[1]...@opcode[2]])
      end
      
      def equal
        @content += @b[@opcode[3]...@opcode[4]]
      end
    
      # Using this as op_helper would be equivalent to the first version of diff.rb by Bill Atkins
      def op_helper_simple(tagname, tagclass, to_add)
        @content << %(<#{tagname} class="#{tagclass}">) << to_add << %(</#{tagname}>)
      end
      
      # Tries to put <p> tags or newline chars before the opening diff tags (<ins> or <del>)
      # or after the ending diff tags.
      # As a result the diff tags should be the "most inside" possible.
      def op_helper(tagname, tagclass, to_add)
        predicate_methods = [:tab?, :newline?, :close_tag?, :open_tag?]
        content_to_skip   = Proc.new do |item| 
          predicate_methods.any? {|predicate| HTMLDiff.send(predicate, item)}
        end

        unless to_add.any? {|element| content_to_skip.call element}
          @content << wrap_text(to_add, tagname, tagclass)
        else
          loop do
            @content << to_add and break if to_add.all? {|element| content_to_skip.call element}
            # We are outside of a diff tag
            @content << to_add.shift while content_to_skip.call to_add.first 
            @content << %(<#{tagname} class="#{tagclass}">) 
            # We are inside a diff tag
            @content << to_add.shift until content_to_skip.call to_add.first
            @content << %(</#{tagname}>)
          end
        end
        #remove_empty_diff(tagname, tagclass)
      end

      def wrap_text(text, tagname, tagclass)
        %(<#{tagname} class="#{tagclass}">#{text}</#{tagname}>)
      end

      def remove_empty_diff(tagname, tagclass)
        @content = @content[0...-2] if last_elements_empty_diff?(@content, tagname, tagclass)
      end

      def last_elements_empty_diff?(content, tagname, tagclass)
        content[-2] == %(<#{tagname} class="#{tagclass}">) and content.last == %(</#{tagname}>)
      end
  end
  
  class << self
    include Diff::Utilities

    def diff(a, b)
      a, b = html2list(explode(a)), html2list(explode(b))

      out              = Builder.new(a, b)
      sequence_matcher = Diff::SequenceMatcher.new(a, b)

      sequence_matcher.get_opcodes.each {|opcode| out.do_op(opcode)}

      out.result 
    end
  end 
end

if __FILE__ == $0                                                               
  if ARGV.size == 2                                                             
    puts HTMLDiff.diff(IO.read(ARGV.pop), IO.read(ARGV.pop))                    
  else                                                                          
    puts "Usage: html_diff file1 file2"                                         
  end                                                                           
end 
