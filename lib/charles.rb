require 'thor'
require 'pry'

require_relative 'charles/dav'
require_relative 'charles/smug'
require_relative 'charles/release'
require_relative 'charles/commandline'
require_relative 'charles/fileutils'


class Flatpak < Thor
    desc "rebuild", "Rebuild flatpak"
    def rebuild(*args)
        say "Rebuilding flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            Commandline.run "./rebuild.sh"
        }
    end

    desc "upload", "Upload flatpak"
    def upload(*args)
        say "Upload flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            Commandline.run "./upload.sh"
        }
    end

    desc "merge_develop", "Merge and push the kolabnow branch of the kube repository"
    def merge_develop(*args)
        say "Merging develop into kolabnow"
        Dir.chdir("#{Dir.home}/flatpak/tmp/kube") {
            Commandline.run "git checkout develop"
            Commandline.run "git pull"
            Commandline.run "git checkout kolabnow"
            Commandline.run "git merge develop -m 'Merged branch develop'"
            Commandline.run "git push"
        }
    end

end

class Charles < Thor

    desc "flatpak SUBCOMMAND ...", "Flatpak commands"
    subcommand "flatpak", Flatpak

    desc "schedule SUBCOMMAND ...", "Scheduling commands"
    subcommand "schedule", Dav

    desc "smug SUBCOMMAND ...", "SmugMug commands"
    subcommand "smug", Smug

    desc "release SUBCOMMAND ...", "Release commands"
    subcommand "release", Release

    desc "sshtunnel", "Open ssh tunnel."
    def sshtunnel
        say "Opening ssh tunnel"
        Commandline.run "autossh -f -N -M 6565 tunnel"
    end

end

