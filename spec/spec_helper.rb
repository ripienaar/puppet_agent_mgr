dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/../lib")

require 'rubygems'

gem 'mocha'

require 'rspec'
require 'rspec/mocks'
require 'mocha'
require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'ostruct'
require 'json'

# fake puppet enough just to get by without requiring it to run tests
module Puppet
  def self.[](what)
    what.to_s
  end

  def self.features(features=nil)
    if features
      @features = OpenStruct.new(features)
    else
      @features ||= OpenStruct.new(:microsoft_windows? => false)
    end
  end
end

require 'puppet_agent_mgr'
require 'puppet_agent_mgr/v2/manager'
require 'puppet_agent_mgr/v3/manager'

RSpec.configure do |config|
  config.mock_with :mocha
end

