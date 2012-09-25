require 'rake/clean'
require 'rubygems'
require 'rubygems/package_task'

spec = eval(File.read('puppet_agent_mgr.gemspec'))

Gem::PackageTask.new(spec) do |pkg|
end

desc "Run spec tests"
task :test do
    sh "cd spec;rake"
end

