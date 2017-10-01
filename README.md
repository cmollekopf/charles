The hackable automator. Write code instead of notes.
This is entirely customized for my machine though.

# Commands

charles $SKILLS ...ARGS
charles $SKILLGROUP $SKILLS ...ARGS

# Get it into $PATH

ln -s ~/charles/charles.rb ~/bin/scripts/charles

# Examples

charles kube build
charles kube install
charles kube test

charles releasetarball libkolab
charles setobsversion libkolab 1.4.13.2
charles flatpak rebuild
charles flatpak upload

charles photos backup
charles photos import

charles backup

charles remind Foobar on *
charles schedule Foobar on *
charles todo
charles note

* build: execute some build
* test: execute some tests
* integrate: merge to a branch
* run: exec something
* deploy: push stuff on some server
* backup: push stuff to a backup

# TODO
* Summarize executed skills with success/failure message when done
* Time executed skills
* Make availability of skills dependend on availability of directories
