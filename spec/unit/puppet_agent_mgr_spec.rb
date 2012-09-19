#!/usr/bin/env rspec

require 'spec_helper'

describe PuppetAgentMgr do
  describe "#manager" do
    before do
      PuppetAgentMgr.stubs(:require)
    end

    it "should support puppet 2.x.x managers" do
      Puppet.expects(:version).returns("2.7.12")

      PuppetAgentMgr.manager.class.should == PuppetAgentMgr::V2::Manager
    end

    it "should support puppet 3.x.x managers" do
      Puppet.expects(:version).returns("3.0.0")

      PuppetAgentMgr.manager.class.should == PuppetAgentMgr::V3::Manager
    end

    it "should fail with a friendly error for unsupported puppet versions" do
      Puppet.expects(:version).returns("0.22")

      expect { PuppetAgentMgr.manager }.to raise_error("Cannot manage Puppet version 0")
    end

    it "should fail with a friendly error when it cannot determine the Puppet version" do
      Puppet.expects(:version).returns("x")

      expect { PuppetAgentMgr.manager }.to raise_error("Cannot determine the Puppet major version")
    end
  end
end

