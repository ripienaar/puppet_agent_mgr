module PuppetAgentMgr
  module Common
    extend Common

    # is a catalog being applied rigt now?
    def stopped?
      !applying?
    end

    # is the daemon running but not applying a catalog
    def idling?
      (daemon_present? && !applying?)
    end

    # is the agent enabled
    def enabled?
      !disabled?
    end

    # seconds since the last catalog was applied
    def since_lastrun
      (Time.now - lastrun).to_i
    end

    # if a resource is being managed, resource in the syntax File[/x] etc
    def managing_resource?(resource)
      managed_resources.include?(resource.downcase)
    end

    # how many resources are managed
    def managed_resources_count
      managed_resources.size
    end

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
        return "%d days %d hours %d minutes %02d seconds" % [days, hours, minutes, seconds]

      elsif days == 1
        return "%d day %d hours %d minutes %02d seconds" % [days, hours, minutes, seconds]

      elsif hours > 0
        return "%d hours %d minutes %02d seconds" % [hours, minutes, seconds]

      elsif minutes > 0
        return "%d minutes %02d seconds" % [minutes, seconds]

      else
        return "%02d seconds" % seconds

      end
    end
  end
end
