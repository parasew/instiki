class String
  alias old_format %
  define_method("%") do |data|
    unless data.kind_of?(Hash)
      $VERBOSE = false
      r = old_format(data)
      $VERBOSE = true
      r
    else
      ret = self.clone
      data.each do |k,v|
        ret.gsub!(/\%\(#{k}\)/, v)
      end
      ret
    end
  end
end