module PuppetAgentMgr::V2
  module Unix
    # for a run based on the following options:
    #
    # :foreground_run - runs in the foreground a --test run
    # :signal_daemon - if the daemon is running, sends it USR1 to wake it up
    #
    # else a single background run will be attempted but this will fail if a idling
    # daemon is present and :signal_daemon was false
    def runonce!(opts={})
      raise "Puppet is currently applying a catalog, cannot run now" if applying?
      raise "Puppet is disabled, cannot run now" if disabled?

      if opts.fetch(:foreground_run, false)
        __run_in_foreground
      elsif idling? && opts.fetch(:signal_daemon, true)
        __signal_running_daemon
      else
        raise "Cannot run in the background if the daemon is present" if daemon_present?
        __run_in_background
      end
    end

    # is the agent daemon currently in the unix process list?
    def daemon_present?
      if File.exist?(Puppet[:pidfile])
        return __has_process_for_pid?(File.read(Puppet[:pidfile]))
      end

      return false
    end

    # is the agent currently applying a catalog
    def applying?
      return false if disabled?

      if File::Stat.new(Puppet[:puppetdlockfile]).size > 0
        return __has_process_for_pid(File.read(Puppet[:puppetdlockfile]))
      end

      return false
    rescue
      return false
    end

    def __run_in_foreground
      %x[puppet agent --test --color=false]
    end

    def __run_in_background
      %x[puppet agent --onetime --daemonize]
    end

    def __signal_running_daemon
      pid = File.read(Puppet[:pidfile])

      if has_process_for_pid?(pid)
        begin
          Process.kill("USR1", Integer(pid))
        rescue Exception => e
          raise "Failed to signal the puppet agent at pid %s: %s" % [pid, e.to_s]
        end
      else
        __run_in_background
      end
    end

    def __has_process_for_pid?(pid)
      !!Process.kill(0, Integer(pid)) rescue false
    end
  end
end
