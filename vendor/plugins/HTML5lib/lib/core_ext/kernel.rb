module Kernel
  def silence
    if $VERBOSE
      $VERBOSE = false
      yield
      $VERBOSE = true
    else
      yield
    end
  end
end

  