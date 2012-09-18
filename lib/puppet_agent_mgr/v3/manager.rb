module PuppetAgentMgr::V3
  class Manager
    if Puppet.features.microsoft_windows?
      require 'puppet_agent_mgr/v3/windows'
      include Windows
    else
      require 'puppet_agent_mgr/v3/unix'
      include Unix
    end

    include PuppetAgentMgr::Common

    # enables the puppet agent, it can now start applying catalogs again
    def enable!
      raise "Already enabled" if enabled?
      File.unlink(Puppet[:agent_disabled_lockfile])
    end

    # disable the puppet agent, on version 2.x the message is ignored
    def disable!(msg=nil)
      raise "Already disabled" unless enabled?

      msg = "Disabled using the Ruby API at %s" % Time.now.strftime("%c")

      atomic_file(Puppet[:agent_disabled_lockfile]) do |f|
        f.print(JSON.dump(:disabled_message => msg))
      end

      msg
    end

    # if a resource is being managed, resource in the syntax File[/x] etc
    def managing_resource?(resource)
      managed_resources.include?(resource.downcase)
    end

    # how many resources are managed
    def managed_resources_count
      managed_resources.size
    end

    # all the managed resources
    def managed_resources
      # need to add some caching here based on mtime of the resources file
      return [] unless File.exist?(Puppet[:resourcefile])

      File.readlines(Puppet[:resourcefile]).map do |resource|
        resource.chomp
      end
    end

    # seconds since the last catalog was applied
    def since_lastrun
      (Time.now - lastrun).to_i
    end

    # epoch time when the last catalog was applied
    def lastrun
      summary = load_summary

      Integer(summary["time"].fetch("last_run", 0))
    end

    # the current lock message, always "" on 2.0
    def lock_message
      if disabled?
        lock_data = JSON.parse(File.read(Puppet[:agent_disabled_lockfile]))
        return lock_data["disabled_message"]
      else
        return ""
      end
    end

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

    # is the agent disabled
    def disabled?
      File.exist?(Puppet[:agent_disabled_lockfile])
    end

    # loads the summary file and makes sure that some keys are always present
    def load_summary
      summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}

      summary.merge!(YAML.load_file(Puppet[:lastrunfile])) if File.exist?(Puppet[:lastrunfile])

      summary["resources"] = {"failed"=>0, "changed"=>0, "total"=>0, "restarted"=>0, "out_of_sync"=>0}.merge!(summary["resources"])

      summary
    end
  end
end
