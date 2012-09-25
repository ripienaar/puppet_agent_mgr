require 'spec_helper'

Puppet.features(:microsoft_windows? => false)

require 'puppet_agent_mgr/v2/manager'

module PuppetAgentMgr::V2
  describe Unix do
    describe "#daemon_present?" do
      it "should return false if the pidfile does not exist" do
        File.expects(:exist?).with("pidfile").returns(false)
        Unix.daemon_present?.should == false
      end

      it "should check the pid if the pidfile exist" do
        File.expects(:exist?).with("pidfile").returns(true)
        File.expects(:read).with("pidfile").returns(1)
        Unix.expects(:has_process_for_pid?).with(1).returns(true)
        Unix.daemon_present?.should == true
      end
    end

    describe "#applying?" do
      it "should return false when disabled" do
        Unix.expects(:disabled?).returns(true)
        Unix.applying?.should == false
      end

      it "should check the pid if the lock file is not empty" do
        stat = OpenStruct.new(:size => 1)
        File::Stat.expects(:new).returns(stat)
        File.expects(:read).with("puppetdlockfile").returns("1")
        Unix.expects(:disabled?).returns(false)
        Unix.expects(:has_process_for_pid).with("1").returns(true)
        Unix.applying?.should == true
      end

      it "should return false if the lockfile is empty" do
        stat = OpenStruct.new(:size => 0)
        File::Stat.expects(:new).returns(stat)
        Unix.expects(:disabled?).returns(false)
        Unix.applying?.should == false
      end

      it "should return false if the lockfile is stale" do
        stat = OpenStruct.new(:size => 1)
        File::Stat.expects(:new).returns(stat)
        File.expects(:read).with("puppetdlockfile").returns("1")
        Unix.expects(:disabled?).returns(false)
        Unix.expects(:has_process_for_pid).with("1").returns(false)
        Unix.applying?.should == false
      end

      it "should return false on any error" do
        Unix.expects(:disabled?).raises("fail")
        Unix.applying?.should == false
      end
    end

    describe "#signal_running_daemon" do
      it "should check if the process is present and send USR1 if present" do
        File.expects(:read).with("pidfile").returns("1")
        Unix.expects(:has_process_for_pid?).with("1").returns(true)
        Process.expects(:kill).with("USR1", 1)

        Unix.signal_running_daemon
      end

      it "should fall back to background run if the pid is stale" do
        File.expects(:read).with("pidfile").returns("1")
        Unix.expects(:has_process_for_pid?).with("1").returns(false)
        Unix.expects(:run_in_background)

        Unix.signal_running_daemon
      end
    end
  end
end
