# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','puppet_agent_mgr/version.rb'])

spec = Gem::Specification.new do |s|
  s.name = 'puppet_agent_mgr'
  s.version = PuppetAgentMgr::VERSION
  s.author = 'R.I.Pienaar'
  s.email = 'rip@devco.net'
  s.homepage = 'http://devco.net/'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Puppet Agent Manager'
  s.description = "A simple library that wraps the logic around the locks, pids, JSON filesu and YAML files that makes up the Puppet Agent status.  Suppots Puppet 2.7.x and 3.0.x."
# Add your other files here if you make them
  s.files = FileList["{README.md,COPYING,lib}/**/*"].to_a
  s.require_paths << 'lib'
  s.has_rdoc = false
  s.add_development_dependency('rake')
end
