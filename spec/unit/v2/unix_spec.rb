require 'spec_helper'

Puppet.features(:microsoft_windows? => false)

require 'puppet_agent_mgr/v2/manager'

module PuppetAgentMgr::V2
  describe Unix do
    describe "#runonce!" do
      it "should raise when it is already applying" do
        Unix.expects(:applying?).returns(true)
        expect { Unix.runonce! }.to raise_error(/Puppet is currently applying/)
      end

      it "should raise when it is disabled" do
        Unix.stubs(:applying?).returns(false)
        Unix.expects(:disabled?).returns(true)
        expect { Unix.runonce! }.to raise_error(/Puppet is disabled/)
      end

      it "should do a foreground run when requested" do
        Unix.stubs(:applying?).returns(false)
        Unix.stubs(:disabled?).returns(false)

        Unix.expects(:__run_in_foreground)
        Unix.expects(:__run_in_background).never
        Unix.expects(:__signal_running_daemon).never

        Unix.runonce!(:foreground_run => true)
      end

      it "should support sending a signal to the daemon when it is idling" do
        Unix.stubs(:applying?).returns(false)
        Unix.stubs(:disabled?).returns(false)
        Unix.expects(:idling?).returns(true)

        Unix.expects(:__run_in_foreground).never
        Unix.expects(:__run_in_background).never
        Unix.expects(:__signal_running_daemon)

        Unix.runonce!
      end

      it "should not signal a daemon when not allowed and it is idling" do
        Unix.stubs(:applying?).returns(false)
        Unix.stubs(:disabled?).returns(false)
        Unix.expects(:idling?).returns(true)
        Unix.expects(:daemon_present?).returns(true)

        Unix.expects(:__run_in_foreground).never
        Unix.expects(:__signal_running_daemon).never
        Unix.expects(:__run_in_background).never

        expect { Unix.runonce!(:signal_daemon => false) }.to raise_error(/Cannot run.+if the daemon is present/)
      end

      it "should do a background run if the daemon is not present" do
        Unix.stubs(:applying?).returns(false)
        Unix.stubs(:disabled?).returns(false)
        Unix.expects(:idling?).returns(false)
        Unix.expects(:daemon_present?).returns(false)

        Unix.expects(:__run_in_foreground).never
        Unix.expects(:__signal_running_daemon).never
        Unix.expects(:__run_in_background)

        Unix.runonce!
      end
    end

    describe "#daemon_present?" do
      it "should return false if the pidfile does not exist" do
        File.expects(:exist?).with("pidfile").returns(false)
        Unix.daemon_present?.should == false
      end

      it "should check the pid if the pidfile exist" do
        File.expects(:exist?).with("pidfile").returns(true)
        File.expects(:read).with("pidfile").returns(1)
        Unix.expects(:__has_process_for_pid?).with(1).returns(true)
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
        Unix.expects(:__has_process_for_pid).with("1").returns(true)
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
        Unix.expects(:__has_process_for_pid).with("1").returns(false)
        Unix.applying?.should == false
      end

      it "should return false on any error" do
        Unix.expects(:disabled?).raises("fail")
        Unix.applying?.should == false
      end
    end

    describe "#__signal_running_daemon" do
      it "should check if the process is present and send USR1 if present" do
        File.expects(:read).with("pidfile").returns("1")
        Unix.expects(:__has_process_for_pid?).with("1").returns(true)
        Process.expects(:kill).with("USR1", 1)

        Unix.__signal_running_daemon
      end

      it "should fall back to background run if the pid is stale" do
        File.expects(:read).with("pidfile").returns("1")
        Unix.expects(:__has_process_for_pid?).with("1").returns(false)
        Unix.expects(:__run_in_background)

        Unix.__signal_running_daemon
      end
    end
  end
end
