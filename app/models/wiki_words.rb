# Contains all the methods for finding and replacing wiki words
module WikiWords
  # In order of appearance: Latin, greek, cyrillian, armenian
  I18N_HIGHER_CASE_LETTERS =
    "ÀÁÂÃÄÅĀĄĂÆÇĆČĈĊĎĐÈÉÊËĒĘĚĔĖĜĞĠĢĤĦÌÍÎÏĪĨĬĮİĲĴĶŁĽĹĻĿÑŃŇŅŊÒÓÔÕÖØŌŐŎŒŔŘŖŚŠŞŜȘŤŢŦȚÙÚÛÜŪŮŰŬŨŲŴÝŶŸŹŽŻ" + 
    "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ" + 
    "ΆΈΉΊΌΎΏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҊҌҎҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӅӇӉӋӍӐӒӔӖӘӚӜӞӠӢӤӦӨӪӬӮӰӲӴӸЖ" +
    "ԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՏՐՑՒՓՔՕՖ"

  I18N_LOWER_CASE_LETTERS =
    "àáâãäåāąăæçćčĉċďđèéêëēęěĕėƒĝğġģĥħìíîïīĩĭįıĳĵķĸłľĺļŀñńňņŉŋòóôõöøōőŏœŕřŗśšşŝșťţŧțùúûüūůűŭũųŵýÿŷžżźÞþßſÐð" +
    "άέήίΰαβγδεζηθικλμνξοπρςστυφχψωϊϋόύώΐ" +
    "абвгдежзийклмнопрстуфхцчшщъыьэюяѐёђѓєѕіїјљћќѝўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁҋҍҏґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӀӂӄӆӈӊӌӎӑӓӕӗәӛӝӟӡӣӥӧөӫӭӯӱӳӵӹ" +
    "աբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆև"

  WIKI_WORD_PATTERN = '[A-Z' + I18N_HIGHER_CASE_LETTERS + '][a-z' + I18N_LOWER_CASE_LETTERS + ']+[A-Z' + I18N_HIGHER_CASE_LETTERS + ']\w+'
  CAMEL_CASED_WORD_BORDER = /([a-z#{I18N_LOWER_CASE_LETTERS}])([A-Z#{I18N_HIGHER_CASE_LETTERS}])/u

  def self.separate(wiki_word, ignore_separation = false)
    if ignore_separation
      wiki_word
    else
      wiki_word.gsub(CAMEL_CASED_WORD_BORDER, '\1 \2')
    end
  end
end