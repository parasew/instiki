#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../test_helper'

class RedClothForTexTest < Test::Unit::TestCase
  def test_basics
    assert_equal '{\bf First Page}', Maruku.new('*First Page*').to_latex
    assert_equal '{\em First Page}', Maruku.new('_First Page_').to_latex
    assert_equal "\\begin{itemize}\n\t\\item A\n\t\t\\item B\n\t\t\\item C\n\t\\end{itemize}", Maruku.new('* A\n* B\n* C').to_latex
  end
  
  def test_blocks
    assert_equal '\section*{hello}', Maruku.new('#hello#').to_latex 
    assert_equal '\subsection*{hello}', Maruku.new('##hello##').to_latex
  end
  
  def test_table_of_contents

source = <<EOL
* [[A]]
** [[B]]
** [[C]]
* D
** [[E]]
*** F
EOL

expected_result = <<EOL
\\pagebreak

\\section{A}
Abe

\\subsection{B}
Babe

\\subsection{C}
\\pagebreak

\\section{D}

\\subsection{E}

\\subsubsection{F}
EOL
    expected_result.chop!
    assert_equal(expected_result, table_of_contents(source, 'A' => 'Abe', 'B' => 'Babe'))
  end
  
  def test_entities
    assert_equal "Beck \\& Fowler are 100\\% cool", RedClothForTex.new("Beck & Fowler are 100% cool").to_tex
  end

  def test_bracket_links
    assert_equal "such a Horrible Day, but I won't be Made Useless", RedClothForTex.new("such a [[Horrible Day]], but I won't be [[Made Useless]]").to_tex
  end
  
  def test_footnotes_on_abbreviations
    assert_equal(
      "such a Horrible Day\\footnote{1}, but I won't be Made Useless", 
      RedClothForTex.new("such a [[Horrible Day]][1], but I won't be [[Made Useless]]").to_tex
    )
  end
  
  def test_subsection_depth
    assert_equal "\\subsubsection*{Hello}", RedClothForTex.new("h4. Hello").to_tex
  end
end
