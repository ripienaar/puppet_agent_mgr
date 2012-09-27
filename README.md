What?
=====

While doing some prototype work of a new MCollective agent to manage Puppet
version 3 I needed to write a bunch of code to wrap the lock files, json files,
pid files and yaml files that makes up the combined status of the Puppet Agent.

The object of this library is to make it easier for external processes like
monitoring scripts, mcollective etc to interface with all the locks and status
files for the Puppet Agent. Puppet sometimes change how it behaves wrt these
files so this API is versioned and returns a version specific manager instance
that represents a consistant API. Currently it understands Puppet 2.7.x and
Puppet 3.0.x.

Additionally it interacts directly with the files in question and not via the
Puppet libraries so it should be a bit faster, I do not know the Puppet
libraries around locking and these files using the Puppet libraries directly
might be isolated enough that there could be scope to DRY this up.

It does require the puppet libraries and fetches the settings from the Puppet
library.  At present it makes no effort to ensure it parses the right file or
right section out of the file, this is a major short coming but I am not
familiar enough with the Puppet settings classes to figure out the run_mode and
so forth in the time I had.

This is a work in progress specifically a few outstanding questions remain:

  * Puppet has a *run_mode* concept, I need to use this to be sure I get the agent config and not some other section
  * The *runonce* method should support applying tags, noop and a few other behaviors
  * It supports Windows and Unix seperation but does not currently do any Windows stuff

Available Methods?
------------------

  * *enable!* Unlocks a locked daemon, raises when already unlocked.
  * *disable!(msg)* Locks a daemon, on versions that supports a message writes the message. Raises when already locked.
  * *managing_resource?(resource)* True or False if a resource is managed, resource formatted like *File[/srv/www]*
  * *managed_resource_count* How many resources are managed on this node
  * *managed_resources* An array of resource names
  * *since_lastrun* Seconds since the last catalog was applied
  * *lastrun* Unix epoch that the last catalog was applied in local time
  * *lock_message* The message used to lock the daemon, empty string when not supported
  * *stopped?* true when no catalog is being applied
  * *applying?* true when a catalog is being applied now
  * *idling?* if the daemon is in the process list and it is not applying
  * *enabled?* is the agent unlocked? it could at this point apply a catalog
  * *disabled?* is the agent locked?
  * *load_summary* loads the last run summary, returns a emptyish structure when nothing is found
  * *daemon_present?* is the daemon in the process lsit
  * *runonce!* triggers a puppet agent. Can signal a running daemon and take various flags commonly used

Using?
------

You can obtain basic status, this is a convenience wrapper around all the status behavior
in the library:

    >> require 'puppet_agent_mgr'
    => true
    >> m = PuppetAgentMgr.manager
    => #<PuppetAgentMgr::V2::Manager:0x7fe2edf76070>
    >> m.status
    {:status=>"disabled", :applying=>false, :lastrun=>1347897634,
     :message=>"Currently disabled; last completed run 18 hours 59 minutes 17 seconds ago",
     :disable_message=>"", :enabled=>false, :since_lastrun=>68357, :daemon_present=>false}

You can enable/disable:

    >> m.enabled?
    false
    >> m.enable!
    => 1
    >> m.enabled?
    => true

You can find out if there is currently a daemon in the process list and if it's
busy applying a catalog:

    >> m.daemon_present?
    => false
    >> m.applying?
    => false
    >> m.idling?
    => false

You can find out when last it applied a catalog:

    >> m.lastrun
    => 1347897634
    >> m.since_lastrun
    => 68615

And you can load the summary, it will make some effort to normalize the data
so you'll always get at least some sanely structured content:

    >> m.load_summary
    => {"events"=>{"total"=>0, "success"=>0, "failure"=>0},
        "resources"=>{"restarted"=>0, "total"=>7, "failed"=>0, "skipped"=>6, "scheduled"=>0,
                      "failed_to_restart"=>0, "changed"=>0, "out_of_sync"=>0},
        "changes"=>{"total"=>0}, "time"=>{"total"=>0.040585, "last_run"=>1347897634,
                                          "config_retrieval"=>0.040399, "filebucket"=>0.000186},
        "version"=>{"puppet"=>"2.7.17", "config"=>1347897634}}

Puppet records which resources it is managing, this information is available:

    >> m.managed_resources_count
    => 569
    >> m.managed_resources
    => [ .........]
    >> m.managing_resource?("File[/srv/www]")
    => false

And finally you can kick off a run:

    >> m.runonce :foreground_run => true
    => "..full puppet run output here"
    >> m.runonce
    => ""

You can limit it to specific tags:

    >> m.runonce(:tags => ["foo", "bar"])
    => ""

You can do a noop run:

    >> m.runonce(:noop => true)
    => ""

And specify an environment:

    >> m.runonce(:environment => "development")
    => ""

And even a custom master and port:

    >> m.runonce(:server => "dev-puppet.example.com:1234")
    => ""

You can force splaying:

    >> m.runonce(:splay => true)
    => ""

...or force disable it

    >> m.runonce(:splay => false)
    => ""

...with a custom time limit

    >> m.runonce(:splay => true, :splaylimit=100)
    => ""

When doing noop, tags limited, specific host or specific environment runs it
will raise an exception if the daemon is already present as the only option
available then is to trigger an immediate run

Contact?
========

R.I.Pienaar / rip@devco.net / @ripienaar / http://devco.net/

