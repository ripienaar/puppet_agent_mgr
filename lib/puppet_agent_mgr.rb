require 'puppet_agent_mgr/common'

module PuppetAgentMgr
  def self.manager
    # puppet 2 requires this, 3 probably just ignores it
    $puppet_application_name = :agent

    require 'puppet'
    require 'json'

    if Puppet.version =~ /^(\d+)/
      case $1
        when "2"
          require 'puppet_agent_mgr/v2/manager'
          return PuppetAgentMgr::V2::Manager.new

        when "3"
          require 'puppet_agent_mgr/v3/manager'
          return PuppetAgentMgr::V3::Manager.new

        else
          raise "Cannot manage Puppet version %s" % $1
      end
    else
      raise "Cannot determine the Puppet major version"
    end
  end
end
