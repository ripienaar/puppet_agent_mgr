#!/usr/bin/env rspec

require 'spec_helper'

Puppet.features(:microsoft_windows? => false)

require 'puppet_agent_mgr/v2/manager'

module PuppetAgentMgr::V2
  describe Manager do
    before :each do
      @manager = PuppetAgentMgr::V2::Manager.new
    end

    describe "#enable!" do
      it "should raise when it's already enabled" do
        @manager.expects(:enabled?).returns(true)
        expect { @manager.enable! }.to raise_error("Already enabled")
      end

      it "should attempt to remove the lock file" do
        File.expects(:unlink).with(Puppet[:puppetdlockfile])
        @manager.expects(:enabled?).returns(false)
        @manager.enable!
      end
    end

    describe "#disable!" do
      it "should raise when it's already disabld" do
        @manager.expects(:enabled?).returns(false)
        expect { @manager.disable! }.to raise_error("Already disabled")
      end

      it "should create the lockfile with the correct path" do
        @manager.expects(:enabled?).returns(true)

        File.expects(:open).with("puppetdlockfile", "w")

        @manager.disable!
      end
    end

    describe "#managed_resources" do
      it "should return an empty list when the resources file does not exist" do
        File.expects(:exist?).with("resourcefile").returns(false)

        @manager.managed_resources.should == []
      end

      it "should read the file and return the contents if it exist" do
        File.expects(:exist?).with("resourcefile").returns(true)
        File.expects(:readlines).with("resourcefile").returns(["file[x]\n", "file[y]\n"])

        @manager.managed_resources.should == ["file[x]", "file[y]"]
      end
    end

    describe "#lastrun" do
      it "should retrieve the previous run time from the summary" do
        summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}
        summary["time"] = {"last_run" => Time.now.to_i}

        @manager.expects(:load_summary).returns(summary)
        @manager.lastrun.should == summary["time"]["last_run"]
      end

      it "should default to 0 when no time could be found" do
        summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}

        @manager.expects(:load_summary).returns(summary)
        @manager.lastrun.should == 0
      end
    end

    describe "#lock_message" do
      it "should always return an empty string" do
        @manager.lock_message.should == ""
      end
    end

    describe "#disabled?" do
      it "should return false if the lock file does not exist" do
        File.expects(:exist?).with("puppetdlockfile").returns(false)
        File::Stat.expects(:new).never
        @manager.disabled?.should == false
      end

      it "should return false if the lock file is not empty" do
        stat = OpenStruct.new(:zero? => false)
        File.expects(:exist?).with("puppetdlockfile").returns(true)
        File::Stat.expects(:new).with("puppetdlockfile").returns(stat)
        @manager.disabled?.should == false
      end

      it "should return true if it is zero size" do
        stat = OpenStruct.new(:zero? => true)
        File.expects(:exist?).with("puppetdlockfile").returns(true)
        File::Stat.expects(:new).with("puppetdlockfile").returns(stat)
        @manager.disabled?.should == true
      end
    end

    describe "#load_summary" do
      it "should return a default structure when no file is found" do
        File.expects(:exist?).with("lastrunfile").returns(false)

        @manager.load_summary.should == {"changes" => {},
                                         "time" => {},
                                         "resources" => {"failed"=>0, "changed"=>0, "total"=>0, "restarted"=>0, "out_of_sync"=>0},
                                         "version" => {},
                                         "events" => {}}
      end

      it "should return merged results if the file is found" do
        yamlfile = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "fixtures", "last_run_summary.yaml"))
        Puppet.expects(:[]).with(:lastrunfile).returns(yamlfile).twice

        @manager.load_summary.should == {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}.merge(YAML.load_file(yamlfile))
      end
    end
  end
end
