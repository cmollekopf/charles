The hackable automator. Write code instead of notes.
This is entirely customized for my machine though.

# Commands

charles $CAPABILITY ...ARGS
charles $CAPABILITYGROUP $CAPABILITY ...ARGS

# Get it into $PATH

ln -s ~/charles/charles.rb ~/bin/scripts/charles

# Examples

charles build kube
charles test kube
charles integrate kolabnowkube-flatpak
charles build kolabnowkube-flatpak
charles run kolabnowkube-flatpak
charles deploy kolabnowkube-flatpak
charles releasetarball libkolab
charles setobsversion libkolab 1.4.13.2
charles flatpak rebuild
charles flatpak upload

charles backup photos
charles import photos

* build: execute some build
* test: execute some tests
* integrate: merge to a branch
* run: exec something
* deploy: push stuff on some server
* backup: push stuff to a backup
