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

    def run_in_foreground(clioptions)
      command =["puppet", "agent", "--test", "--color=false"]
      command.concat(clioptions)

      %x[#{command.join(' ')}]
    end

    def run_in_background(clioptions)
      command =["puppet", "agent", "--onetime", "--daemonize", "--color=false"]
      command.concat(clioptions)

      %x[#{command.join(' ')}]
    end

    def validate_name(name)
      if name.length == 1
        return false unless name =~ /\A[a-zA-Z]\Z/
      else
        return false unless name =~ /\A[a-zA-Z0-9_]+\Z/
      end

      true
    end

    def create_common_puppet_cli(noop, tags, environment, server)
      opts = []

      (host, port) = server.to_s.split(":")

      raise("Invalid hostname '%s' specified" % host) if host && !(host =~ /\A(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\Z/)
      raise("Invalid master port '%s' specified" % port) if port && !(port =~ /\A\d+\Z/)
      raise("Invalid environment '%s' specified" % environment) if environment && !validate_name(environment)

      unless tags.empty?
        [tags].flatten.each do |tag|
          tag.split("::").each do |part|
            raise("Invalid tag '%s' specified" % tag) unless validate_name(part)
          end
        end

        opts << "--tags %s" % tags.join(",") if !tags.empty?
      end

      opts << "--noop" if noop
      opts << "--environment %s" % environment if environment
      opts << "--server %s" % host if host
      opts << "--masterport %s" % port if port

      opts
    end

    # do a run based on the following options:
    #
    # :foreground_run - runs in the foreground a --test run
    # :signal_daemon  - if the daemon is running, sends it USR1 to wake it up
    # :noop           - does a noop run if possible
    # :tags           - an array of tags to limit the run to
    # :environment    - the environment to run
    # :server         - the puppet master to use, can be some.host or some.host:port
    #
    # else a single background run will be attempted but this will fail if a idling
    # daemon is present and :signal_daemon was false
    def runonce!(options={})
      valid_options = [:noop, :signal_daemon, :foreground_run, :tags, :environment, :server]

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
      server = options[:server]

      clioptions = create_common_puppet_cli(noop, tags, environment, server)

      if idling? && signal_daemon && !clioptions.empty?
        raise "Cannot specify any custom puppet options when the daemon is running"
      end

      if foreground_run
        run_in_foreground(clioptions)
      elsif idling? && signal_daemon
        signal_running_daemon
      else
        raise "Cannot run in the background if the daemon is present" if daemon_present?
        run_in_background(clioptions)
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
