require 'syntax'

module Syntax

  class SQLite < Tokenizer
    
    def self.add_function(name)
      SQLite_PREDEFINED_FUNCTIONS << name
    end

    SQLite_PREDEFINED_FUNCTIONS = Set.new %w{abs avg coalesce count glob
      hex ifnull last_insert_rowid length like load_extension lower 
      ltrim max min sum nullif
      quote random randomblob replace round
      rtrim soundex sqlite_version substr total
      trim typeof upper zeroblob
      date time datetime julianday
      strftime over} unless const_defined?(:SQLite_PREDEFINED_FUNCTIONS)

    SQLite_KEYWORDS = Set.new %w{abort add after all alter analyze
      asc attach autoincrement before by cascade change character
      check commit conflict constraint create cross  collate
      current_date current_time current_timestamp database default
      deferrable deferred delete desc detach distinct drop each
      escape except exclusive explain fail for foreign from
      full group having if ignore immediate
      index initially inner insert instead intersect into is
      join key left limit modify natural of offset on or order
      outer plan pragma primary query raise references reindex
      rename replace restrict right rollback row select set
      table temp temporary to transaction trigger union
      unique update using vacuum values view virtual
      where partition} unless const_defined?(:SQLite_KEYWORDS)

    SQLite_DATATYPES = Set.new %w{null none text numeric integer
      text blob int varchar char real float
      double} unless const_defined?(:SQLite_DATATYPES)

    SQLite_OPERATORS = Set.new %w{not escape isnull notnull between and
      in exists case when then else begin end cast as
      like glob regexp < >  || * / % + - << >>
      & | <= >= = == != <>
      match} unless const_defined?(:SQLite_OPERATORS)
    
    def step
      case
      when scan(/\s+/)
        start_group :normal, matched
      when scan(%r{ "(?: \\. | \\" | [^"\n])*" }x)
        start_group :string, matched
      when scan(%r{ '(?: \\. | \\' | [^'\n])*' }x )
        start_group :string, matched
      when (scan(/[a-z_][a-z_\d]+/i) or scan(/[<>\|\*%&!=]+/))
        m = matched.downcase
        if SQLite_PREDEFINED_FUNCTIONS.include?( m )
          start_group :function, matched
        elsif SQLite_KEYWORDS.include?( m )
          start_group :keyword, matched
        elsif SQLite_DATATYPES.include?( m )
          start_group :datatype, matched
        elsif SQLite_OPERATORS.include?( m )
          start_group :operator, matched
        else
          start_group :ident, matched
        end
      when scan(/--.*$/)
        start_group :comment, matched
      else
        start_group :other, scan(/./x)
      end
    end

  end

  SYNTAX["sqlite"] = SQLite

end
