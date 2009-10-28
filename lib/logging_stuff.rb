class Logger
  class LogDevice

  private
    def shift_log_age
      #For Passenger, restart the server when rotating log files.
      FileUtils.touch Rails.root.join("tmp", "restart.txt") if defined?(PhusionPassenger)
      (@shift_age-3).downto(0) do |i|
        if FileTest.exist?("#{@filename}.#{i}")
          File.rename("#{@filename}.#{i}", "#{@filename}.#{i+1}")
        end
      end
      @dev.close
      File.rename("#{@filename}", "#{@filename}.0")
      @dev = create_logfile(@filename)
      return true
    end

  end
end
