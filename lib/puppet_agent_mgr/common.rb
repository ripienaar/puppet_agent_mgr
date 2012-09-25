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

    def run_in_foreground(noop, tags, environment)
      command =["puppet", "agent", "--test", "--color=false"]
      command << "--noop" if noop
      command << "--tags %s" % tags.join(",") if !tags.empty?
      command << "--environment %s" % environment if environment

      %x[#{command.join(' ')}]
    end

    def run_in_background(noop, tags, environment)
      command =["puppet", "agent", "--onetime", "--daemonize", "--color=false"]
      command << "--noop" if noop
      command << "--tags %s" % tags.join(",") if !tags.empty?
      command << "--environment %s" % environment if environment

      %x[#{command.join(' ')}]
    end

    # do a run based on the following options:
    #
    # :foreground_run - runs in the foreground a --test run
    # :signal_daemon  - if the daemon is running, sends it USR1 to wake it up
    # :noop           - does a noop run if possible
    # :tags           - an array of tags to limit the run to
    # :environment    - the environment to run
    #
    # else a single background run will be attempted but this will fail if a idling
    # daemon is present and :signal_daemon was false
    def runonce!(options={})
      valid_options = [:noop, :signal_daemon, :foreground_run, :tags, :environment]

      options.keys.each do |opt|
        raise("Unknown option %s specified" % opt) unless valid_options.include?(opt)
      end

      raise "Puppet is currently applying a catalog, cannot run now" if applying?
      raise "Puppet is disabled, cannot run now" if disabled?

      noop = options.fetch(:noop, false)
      signal_daemon = options.fetch(:signal_daemon, true)
      foreground_run = options.fetch(:foreground_run, false)
      environment = options[:environment]
      tags = [ options[:tags] ].flatten.compact

      validate_name(environment, "environment") if environment
      tags.flatten.each {|input| validate_name(input, "tag") }

      if idling? && signal_daemon && (noop || !tags.empty? || environment)
        raise "Cannot specify tags, noop or environemnt when the daemon is running"
      end

      if foreground_run
        run_in_foreground(noop, tags, environment)
      elsif idling? && signal_daemon
        signal_running_daemon
      else
        raise "Cannot run in the background if the daemon is present" if daemon_present?
        run_in_background(noop, tags, environment)
      end
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

    # puppet classes, tags and enviroments have strict rules
    # plus we wouldnt want to be subject to shell injections
    def validate_name(name, description)
      raise("Invalid input for '%s' supplied" % description) unless name =~ /\A[a-z][a-z0-9_]*\Z/
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
