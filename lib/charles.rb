require 'thor'
require 'pry'

require_relative 'charles/dav'
require_relative 'charles/smug'
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

class Git
    def self.is_clean?
        Commandline.run "git status" do |output|
            return output.include? 'working directory clean'
        end
    end

    def self.update(branch)
        Commandline.run "git checkout #{branch}"
        Commandline.run "git pull"
    end

    def self.merge(source, target, message)
        Commandline.run "git checkout #{target}"
        Commandline.run "git merge #{source} -m '#{message}'"
    end
end

class Release < Thor
    no_commands {

        def parseVersionNumber(s)
            s.scan(/(\d+)/).flatten.map(&:to_i)
        end

        def cleanCheckout(branch)
            unless Git.is_clean?
                say "Directory is not clean"
                if yes? "Stash?"
                    Commandline.run "git stash"
                else
                    exit
                end
            end
            Commandline.run "git checkout #{branch}"
            Commandline.run "git pull"
        end

        def createReleaseTarball(tag)
            Commandline.run "git archive --prefix=#{tag}/ HEAD | gzip -c > #{tag}.tar.gz"
        end

        def tagNewRelease(name)
            latestTag = Commandline.run "git describe --tags --abbrev=0"
            latestTagCommit = Commandline.run "git log #{latestTag} -n 1 --pretty=format:'%H'"
            latestCommit = Commandline.run "git log -n 1 --pretty=format:'%H'"
            if latestTagCommit == latestCommit
                say "Release commit is available: " + latestTagCommit
                return latestTag
            end
            Fileutils.replaceInFile("CMakeLists.txt", /VERSION_KOLAB (.*)\)/) { |s| (s.to_i + 1).to_s }
            latestVersionNumber = parseVersionNumber(latestTag)
            versionNumber = "#{latestVersionNumber[0]}.#{latestVersionNumber[1]}.#{latestVersionNumber[2]}.#{latestVersionNumber[3] + 1}"
            tag = "#{name}-#{versionNumber}"
            Commandline.run "git commit -a -m 'Prepared release of #{tag}'"
            Commandline.run "git tag -u mollekopf@kolabsys.com -s #{tag} -m 'Release of #{tag}'"
            return tag
        end

    }

    desc "git_kdepim", ""
    def git_kdepim
        say "Release"
        Dir.chdir("#{Dir.home}/kdebuild/kdepim/source/kdepim") {
            branch = "kolab/integration/4.13.0"
            name = "kdepim"
            cleanCheckout(branch)
            tag = tagNewRelease(name)

            # Commandline.run "git push origin #{branch}:#{branch}"
            # Commandline.run "git push origin #{tag}:#{tag}"
            createReleaseTarball(tag)
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

