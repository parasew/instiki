#coding: utf-8
# Contains all the methods for finding and replacing wiki words
module WikiWords
  # In order of appearance: Latin, greek, cyrillic, armenian
  I18N_HIGHER_CASE_LETTERS =
    "ÀÁÂÃÄÅĀĄĂÆÇĆČĈĊĎĐÈÉÊËĒĘĚĔĖĜĞĠĢĤĦÌÍÎÏĪĨĬĮİĲĴĶŁĽĹĻĿÑŃŇŅŊÒÓÔÕÖØŌŐŎŒŔŘŖŚŠŞŜȘŤŢŦȚÙÚÛÜŪŮŰŬŨŲŴŶŸȲÝŹŽŻ" + 
    "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ" + 
    "ΆΈΉΊΌΎΏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҊҌҎҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӅӇӉӋӍӏӐӒӔӖӘӚӜӞӠӢӤӦӨӪӬӮӰӲӴӸЖ" +
    "ԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖ"

  I18N_LOWER_CASE_LETTERS =
    "àáâãäåāąăæçćĉċčďđèéêëēęěĕėƒĝğġģĥħìíîïīĩĭįıĳĵķĸłľĺļŀñńňņŉŋòóôõöøōŏőœŕřŗśŝšşșťţŧțùúûüūůűŭũųŵýÿŷžżźÞþßſð" +
    "άέήίΰαβγδεζηθικλμνξοπρςστυφχψωϊϋόύώΐ" +
    "абвгдежзийклмнопрстуфхцчшщъыьэюяѐёђѓєѕіїјљћќѝўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁҋҌҍҏґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӀӂӄӆӈӊӌӎӑӓӕӗәӛӝӟӡӣӥӧөӫӭӯӱӳӵӹ" +
    "աբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆև"

  WIKI_WORD_PATTERN = '[A-Z' + I18N_HIGHER_CASE_LETTERS + ']+[a-z' + I18N_LOWER_CASE_LETTERS + ']+[A-Z' + I18N_HIGHER_CASE_LETTERS + ']\w+'
  CAMEL_CASED_WORD_BORDER = /([a-z#{I18N_LOWER_CASE_LETTERS}])([A-Z#{I18N_HIGHER_CASE_LETTERS}])/u

  def self.separate(wiki_word)
    wiki_word.gsub(CAMEL_CASED_WORD_BORDER, '\1 \2')
  end

end
