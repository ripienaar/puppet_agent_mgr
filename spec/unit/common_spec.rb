#!/usr/bin/env rspec

require 'spec_helper'

module PuppetAgentMgr
  module Common
    describe "validate_name" do
      it "should test single character variable names" do
        Common.validate_name("1").should == false
        Common.validate_name("a").should == true
        Common.validate_name("_").should == false
      end

      it "should test multi character variable names" do
        Common.validate_name("1a").should == true
        Common.validate_name("ab").should == true
        Common.validate_name("a_b").should == true
        Common.validate_name("a-b").should == false
      end
    end

    describe "#create_common_puppet_cli" do
      it "should test the host and port" do
        expect { Common.create_common_puppet_cli(nil, [], nil, "foo bar") }.to raise_error(/Invalid hostname/)
        expect { Common.create_common_puppet_cli(nil, [], nil, "foo:bar") }.to raise_error(/Invalid master port/)

        Common.create_common_puppet_cli(nil, [], nil, "foo:10").should == ["--server foo", "--masterport 10"]
        Common.create_common_puppet_cli(nil, [], nil, "foo").should == ["--server foo"]
      end

      it "should support noop" do
        Common.create_common_puppet_cli(true, [], nil, nil).should == ["--noop"]
      end

      it "should support tags" do
        Common.create_common_puppet_cli(nil, ["one"], nil, nil).should == ["--tags one"]
        Common.create_common_puppet_cli(nil, ["one", "two"], nil, nil).should == ["--tags one,two"]
      end

      it "should support environment" do
        Common.create_common_puppet_cli(nil, [], "production", nil).should == ["--environment production"]
      end

      it "should sanity check environment" do
        expect { Common.create_common_puppet_cli(nil, [], "prod uction", nil) }.to raise_error("Invalid environment 'prod uction' specified")
      end

      it "should sanity check tags" do
        expect { Common.create_common_puppet_cli(nil, ["one", "tw o"], nil, nil) }.to raise_error("Invalid tag 'tw o' specified")
        expect { Common.create_common_puppet_cli(nil, ["one::two", "tw o"], nil, nil) }.to raise_error("Invalid tag 'tw o' specified")
      end
    end

    describe "#runonce!" do
      it "should only accept valid option keys" do
        expect { Common.runonce! :rspec => true }.to raise_error("Unknown option rspec specified")
      end

      it "should fail when a daemon is idling and tags, environment or noop is specified" do
        Common.stubs(:idling?).returns(true)
        Common.stubs(:applying?).returns(false)
        Common.stubs(:disabled?).returns(false)

        expect { Common.runonce!(:noop => true) }.to raise_error("Cannot specify any custom puppet options when the daemon is running")
        expect { Common.runonce!(:environment => "production") }.to raise_error("Cannot specify any custom puppet options when the daemon is running")
      end

      it "should raise when it is already applying" do
        Common.expects(:applying?).returns(true)
        expect { Common.runonce! }.to raise_error(/Puppet is currently applying/)
      end

      it "should raise when it is disabled" do
        Common.stubs(:applying?).returns(false)
        Common.expects(:disabled?).returns(true)
        expect { Common.runonce! }.to raise_error(/Puppet is disabled/)
      end

      it "should do a foreground run when requested" do
        Common.stubs(:applying?).returns(false)
        Common.stubs(:disabled?).returns(false)
        Common.stubs(:daemon_present?).returns(false)

        Common.expects(:run_in_foreground)
        Common.expects(:run_in_background).never
        Common.expects(:signal_running_daemon).never

        Common.runonce!(:foreground_run => true)
      end

      it "should support sending a signal to the daemon when it is idling" do
        Common.stubs(:applying?).returns(false)
        Common.stubs(:disabled?).returns(false)
        Common.expects(:idling?).returns(true).twice

        Common.expects(:run_in_foreground).never
        Common.expects(:run_in_background).never
        Common.expects(:signal_running_daemon)

        Common.runonce!
      end

      it "should not signal a daemon when not allowed and it is idling" do
        Common.stubs(:applying?).returns(false)
        Common.stubs(:disabled?).returns(false)
        Common.expects(:idling?).returns(true).twice
        Common.expects(:daemon_present?).returns(true)

        Common.expects(:run_in_foreground).never
        Common.expects(:signal_running_daemon).never
        Common.expects(:run_in_background).never

        expect { Common.runonce!(:signal_daemon => false) }.to raise_error(/Cannot run.+if the daemon is present/)
      end

      it "should do a background run if the daemon is not present" do
        Common.stubs(:applying?).returns(false)
        Common.stubs(:disabled?).returns(false)
        Common.expects(:idling?).returns(false).twice
        Common.expects(:daemon_present?).returns(false)

        Common.expects(:run_in_foreground).never
        Common.expects(:signal_running_daemon).never
        Common.expects(:run_in_background)

        Common.runonce!
      end
    end

    describe "#stopped?" do
      it "should be the opposite of applying?" do
        Common.expects(:applying?).returns(false)
        Common.stopped?.should == true
      end
    end

    describe "#idling?" do
      it "should be true when the daemon is present and it is not applying a catalog" do
        Common.expects(:daemon_present?).returns(true)
        Common.expects(:applying?).returns(false)
        Common.idling?.should == true
      end

      it "should be false when the daemon is not present" do
        Common.expects(:daemon_present?).returns(false)
        Common.expects(:applying?).never
        Common.idling?.should == false
      end

      it "should be false when the agent is applying a catalog" do
        Common.expects(:daemon_present?).returns(true)
        Common.expects(:applying?).returns(true)
        Common.idling?.should == false
      end
    end

    describe "#enabled?" do
      it "should be the opposite of disabled?" do
        Common.expects(:disabled?).returns(false)
        Common.enabled?.should == true
      end
    end

    describe "#since_lastrun" do
      it "should correctly calculate the time based on lastrun" do
        lastrun = Time.now - 10
        time = Time.now

        Time.expects(:now).returns(time)
        Common.expects(:lastrun).returns(lastrun)

        Common.since_lastrun.should == 10
      end

    end

    describe "#managing_resource?" do
      it "should correctly report the managed state" do
        Common.expects(:managed_resources).returns(["file[x]"]).twice

        Common.managing_resource?("File[x]").should == true
        Common.managing_resource?("File[y]").should == false
      end
    end

    describe "#managed_resources_count" do
      it "should report the right size" do
        Common.expects(:managed_resources).returns(["file[x]"])

        Common.managed_resources_count.should == 1
      end
    end

    describe "#status" do
      time = Time.now
      lastrun = (time - 10).to_i
      Time.stubs(:now).returns(time)

      Common.expects(:applying?).returns(true)
      Common.expects(:enabled?).returns(true)
      Common.expects(:daemon_present?).returns(true)
      Common.expects(:lastrun).returns(lastrun).twice
      Common.expects(:lock_message).returns("locked")

      Common.status.should == {:applying => true,
                               :daemon_present => true,
                               :disable_message => "locked",
                               :enabled => true,
                               :lastrun => lastrun,
                               :since_lastrun => 10,
                               :message => "Currently applying a catalog; last completed run 10 seconds ago",
                               :status => "applying a catalog"}
    end

    describe "#atomic_file" do
      it "should create a temp file in the right directory and rename it" do
        file = StringIO.new
        file.expects(:path).returns("/tmp/x.xxx")
        file.expects(:puts).with("hello world")
        File.expects(:rename).with("/tmp/x.xxx", "/tmp/x")
        Tempfile.expects(:new).with("x", "/tmp").returns(file)

        Common.atomic_file("/tmp/x") {|f| f.puts "hello world"}
      end
    end

    describe "seconds_to_human" do
      it "should correctly turn seconds into human times" do
        Common.seconds_to_human(1).should == "01 seconds"
        Common.seconds_to_human(61).should == "1 minutes 01 seconds"
        Common.seconds_to_human((61*61)).should == "1 hours 2 minutes 01 seconds"
        Common.seconds_to_human((24*61*61)).should == "1 day 0 hours 48 minutes 24 seconds"
        Common.seconds_to_human((48*61*61)).should == "2 days 1 hours 36 minutes 48 seconds"
      end
    end
  end
end
