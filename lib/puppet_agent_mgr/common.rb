module PuppetAgentMgr
  module Common
    # simple utility to return a hash with lots of useful information about the state of the agent
    def status
      status = {:applying => applying?,
                :enabled => enabled?,
                :daemon_present => daemon_present?,
                :lastrun => lastrun,
                :disable_message => lock_message,
                :since_lastrun => (Time.now.to_i - lastrun)}

      if !status[:enabled]
        status[:status] = "disabled"

      elsif status[:applying]
        status[:status] = "applying a catalog"

      elsif status[:daemon_present] && status[:applying]
        status[:status] = "idling"

      elsif !status[:applying]
        status[:status] = "stopped"

      end

      status[:message] = "Currently %s; last completed run %s ago" % [status[:status], seconds_to_human(status[:since_lastrun])]

      status
    end

    def atomic_file(file)
      tempfile = Tempfile.new(File.basename(file), File.dirname(file))

      yield(tempfile)

      tempfile.close
      File.rename(tempfile.path, file)
    end

    def seconds_to_human(seconds)
      days = seconds / 86400
      seconds -= 86400 * days

      hours = seconds / 3600
      seconds -= 3600 * hours

      minutes = seconds / 60
      seconds -= 60 * minutes

      if days > 1
        return "%d days %02d hours %02d minutes %02d seconds" % [days, hours, minutes, seconds]

      elsif days == 1
        return "%d day %02d hours %02d minutes %02d seconds" % [days, hours, minutes, seconds]

      elsif hours > 0
        return "%d hours %02d minutes %02d seconds" % [hours, minutes, seconds]

      elsif minutes > 0
        return "%d minutes %02d seconds" % [minutes, seconds]

      else
        return "%02d seconds" % seconds

      end
    end
  end
end
