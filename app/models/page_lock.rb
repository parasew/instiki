# Contains all the lock methods to be mixed in with the page
module PageLock
  LOCKING_PERIOD = 30 * 60 # 30 minutes

  attr_reader :locked_by

  def lock(time, locked_by)
    @locked_at, @locked_by = time, locked_by
  end
  
  def lock_duration(time)
    ((time - @locked_at) / 60).to_i unless @locked_at.nil?
  end
  
  def unlock
    @locked_at = nil
  end
  
  def locked?(comparison_time)
    @locked_at + LOCKING_PERIOD > comparison_time unless @locked_at.nil?
  end

end