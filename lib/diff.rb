module HTMLDiff

  Match = Struct.new(:start_in_old, :start_in_new, :size)
  class Match
    def end_in_old
      self.start_in_old + self.size
    end
    
    def end_in_new
      self.start_in_new + self.size
    end
  end
  
  Operation = Struct.new(:action, :start_in_old, :end_in_old, :start_in_new, :end_in_new)

  class DiffBuilder

    def initialize(old_version, new_version)
      @old_version, @new_version = old_version, new_version
      @content = []
    end

    def build
      split_inputs_to_words
      index_new_words
      operations.each {|opcode| perform_operation(opcode)}
      return @content.join
    end

    def split_inputs_to_words
      @old_words = convert_html_to_list_of_words(explode(@old_version))
      @new_words = convert_html_to_list_of_words(explode(@new_version))
    end

    def index_new_words
      @word_indices = {}
      @new_words.each_with_index { |word, i| (@word_indices[word] ||= []) << i }
    end

    def operations
      position_in_old = position_in_new = 0
      operations = []
      matching_blocks.each do |match|
        match_starts_at_current_position_in_old = (position_in_old == match.start_in_old)
        match_starts_at_current_position_in_new = (position_in_new == match.start_in_new)
        
        action_upto_match_positions = 
          case [match_starts_at_current_position_in_old, match_starts_at_current_position_in_new]
          when [false, false]
            :replace
          when [true, false]
            :insert
          when [false, true]
            :delete
          else
            # this happens if the first few words are same in both versions
            :none
          end

        if action_upto_match_positions != :none
          operation_upto_match_positions = 
              Operation.new(action_upto_match_positions, 
                  position_in_old, match.start_in_old, 
                  position_in_new, match.start_in_new)
          operations << operation_upto_match_positions
        end
        match_operation = Operation.new(:equal, 
            match.start_in_old, match.end_in_old, 
            match.start_in_new, match.end_in_new)
        operations << match_operation

        position_in_old = match.end_in_old
        position_in_new = match.end_in_new
      end
      operations
    end

    def matching_blocks
      matching_blocks = []
      recursively_find_matching_blocks(0, @old_words.size, 0, @new_words.size, matching_blocks)
      matching_blocks
    end
    
    def recursively_find_matching_blocks(start_in_old, end_in_old, start_in_new, end_in_new, matching_blocks)
      match = find_match(start_in_old, end_in_old, start_in_new, end_in_new)
      if match
        if start_in_old < match.start_in_old and start_in_new < match.start_in_new
          recursively_find_matching_blocks(
              start_in_old, match.start_in_old, start_in_new, match.start_in_new, matching_blocks) 
        end
        matching_blocks << match
        if match.end_in_old < end_in_old and match.end_in_new < end_in_new
          recursively_find_matching_blocks(
              match.end_in_old, end_in_old, match.end_in_new, end_in_new, matching_blocks)
        end
      end
    end

    def find_match(start_in_old, end_in_old, start_in_new, end_in_new)
      besti, bestj, bestsize = start_in_old, start_in_new, 0
      
      j2len = {}
      
      (start_in_old..end_in_old).step do |i|
        newj2len = {}
        (@word_indices[@old_words[i]] || []).each do |j|
          next  if j < start_in_new
          break if j >= end_in_new
          
          k = newj2len[j] = (j2len[j - 1] || 0) + 1
          if k > bestsize
            besti, bestj, bestsize = i - k + 1, j - k + 1, k
          end
        end
        j2len = newj2len
      end
      
      while besti > start_in_old and bestj > start_in_new and @old_words[besti - 1] == @new_words[bestj - 1]
        besti, bestj, bestsize = besti - 1, bestj - 1, bestsize + 1
      end
      
      while besti + bestsize < end_in_old and bestj + bestsize < end_in_new and
          @old_words[besti + bestsize] == @new_words[bestj + bestsize]
        bestsize += 1
      end
      
      if bestsize == 0 
        return nil
      else 
        return Match.new(besti, bestj, bestsize)
      end
    end
    
    VALID_METHODS = [:replace, :insert, :delete, :equal]
    def perform_operation(operation)
      @operation = operation
      self.send operation.action, operation
    end

    def replace(operation)
      delete(operation, 'diffmod')
      insert(operation, 'diffmod')
    end
    
    def insert(operation, tagclass = 'diffins')
      insert_tag('ins', tagclass, @new_words[operation.start_in_new...operation.end_in_new])
    end
    
    def delete(operation, tagclass = 'diffdel')
       insert_tag('del', tagclass, @old_words[operation.start_in_old...operation.end_in_old])
    end
    
    def equal(operation)
      # no tags to insert, simply copy the matching words from onbe of the versions
      @content += @new_words[operation.start_in_new...operation.end_in_new]
    end
  
    def opening_tag?(item)
      item =~ %r!^\s*<[^>]+>\s*$!
    end

    def closing_tag?(item)
      item =~ %r!^\s*</[^>]+>\s*$!
    end

    def tag?(item)
      opening_tag?(item) or closing_tag?(item)
    end

    # Tries to enclose diff tags (<ins> or <del>) within <p> tags
    # As a result the diff tags should be the "most inside" possible.
    def insert_tag(tagname, cssclass, words)
      unless words.any? { |word| tag?(word) }
        @content << wrap_text(words.join, tagname, cssclass)
      else
        loop do
          break if words.empty?
          @content << words and break if words.all? { |word| tag?(word) }
          # We are outside of a diff tag
          @content << words.shift while not words.empty? and tag?(words.first)
          @content << %(<#{tagname} class="#{cssclass}">) 
          # We are inside a diff tag
          @content << words.shift until words.empty? or tag?(words.first)
          @content << %(</#{tagname}>)
        end
      end
    end

    def wrap_text(text, tagname, cssclass)
      %(<#{tagname} class="#{cssclass}">#{text}</#{tagname}>)
    end

    def explode(sequence)
      sequence.is_a?(String) ? sequence.split(//) : sequence
    end
  
    def end_of_tag?(char)
      char == '>'
    end
  
    def start_of_tag?(char)
      char == '<'
    end
    
    def whitespace?(char)
      char =~ /\s/
    end
  
    def convert_html_to_list_of_words(x, use_brackets = false)
      mode = :char
      current_word  = ''
      words = []
      
      explode(x).each do |char|
        case mode
        when :tag
          if end_of_tag? char
            current_word << (use_brackets ? ']' : '>')
            words << current_word
            current_word = ''
            if whitespace?(char) 
              mode = :whitespace 
            else
              mode = :char
            end
          else
            current_word << char
          end
        when :char
          if start_of_tag? char
            words << current_word unless current_word.empty?
            current_word = (use_brackets ? '[' : '<')
            mode = :tag
          elsif /\s/.match char
            words << current_word unless current_word.empty?
            current_word = char
            mode = :whitespace
          else
            current_word << char
          end
        when :whitespace
          if start_of_tag? char
            words << current_word unless current_word.empty?
            current_word = (use_brackets ? '[' : '<')
            mode = :tag
          elsif /\s/.match char
            current_word << char
          else
            words << current_word unless current_word.empty?
            current_word = char
            mode = :char
          end
        else 
          raise "Unknown mode #{mode.inspect}"
        end
      end
      words << current_word unless current_word.empty?
      words
    end

  end # of class Diff Builder
  
  def diff(a, b)
    DiffBuilder.new(a, b).build
  end
  
end
