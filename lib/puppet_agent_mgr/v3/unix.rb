module PuppetAgentMgr::V3
  module Unix
    extend Unix
    # is the agent daemon currently in the unix process list?
    def daemon_present?
      if File.exist?(Puppet[:pidfile])
        return has_process_for_pid?(File.read(Puppet[:pidfile]))
      end

      return false
    end

    # is the agent currently applying a catalog
    def applying?
      return false if disabled?

      if File::Stat.new(Puppet[:agent_catalog_run_lockfile]).size > 0
        return has_process_for_pid(File.read(Puppet[:agent_catalog_run_lockfile]))
      end

      return false
    rescue
      return false
    end

    def signal_running_daemon
      pid = File.read(Puppet[:pidfile])

      if has_process_for_pid?(pid)
        begin
          Process.kill("USR1", Integer(pid))
        rescue Exception => e
          raise "Failed to signal the puppet agent at pid %s: %s" % [pid, e.to_s]
        end
      else
        run_in_background
      end
    end

    def has_process_for_pid?(pid)
      !!Process.kill(0, Integer(pid)) rescue false
    end
  end
end
