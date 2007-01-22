class Author < String
  attr_accessor :ip
  attr_reader :name
  def initialize(name, ip = nil) 
    @ip = ip
    super(name)
  end

  def name=(value)
    self.gsub!(/.+/, value)
  end
  
  alias_method :name, :to_s
  
  def <=>(other)
    name <=> other.to_s
  end
end