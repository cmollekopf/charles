require 'thor'
require 'pry'

require_relative 'charles/dav'
require_relative 'charles/smug'
require_relative 'charles/commandline'


class Flatpak < Thor
    extend Commandline

    desc "rebuild", "Rebuild flatpak"
    def rebuild(*args)
        say "Rebuilding flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            run "./rebuild.sh"
        }
    end

    desc "upload", "Upload flatpak"
    def upload(*args)
        say "Upload flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            run "./upload.sh"
        }
    end

    desc "merge_develop", "Merge and push the kolabnow branch of the kube repository"
    def merge_develop(*args)
        say "Merging develop into kolabnow"
        Dir.chdir("#{Dir.home}/flatpak/tmp/kube") {
            run "git checkout develop"
            run "git pull"
            run "git checkout kolabnow"
            run "git merge develop -m 'Merged branch develop'"
            run "git push"
        }
    end

end

class Git
    extend Commandline
    def self.is_clean?()
        run "git status" do |output|
            return output.include?('working directory clean')
        end
    end

    def self.update(branch)
        run "git checkout #{branch}"
        run "git pull"
    end

    def self.merge(source, target, message)
        run "git checkout #{target}"
        run "git merge #{source} -m '#{message}'"
    end
end

class Release < Thor
    extend Commandline

    desc "git_kdepim", ""
    def git_kdepim
        say "Merging develop into kolabnow"
        Dir.chdir("#{Dir.home}/kdebuild/kdepim/source/kdepim") {
            unless Git.is_clean?
                say "Directory is not clean"
                return
            end
            # Git.update('develop')
            # Git.merge('develop', 'kolabnow', 'Merged branch develop')
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
        system "autossh -f -N -M 6565 tunnel"
    end

end

