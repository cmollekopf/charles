#!/usr/bin/env ruby

require 'thor'

def run(cmd)
    #Exit if a command fails
    system(cmd) or exit
end

class Flatpak < Thor

    desc "rebuild", "Rebuild flatpak"
    def rebuild(*args)
        say "Rebuilding flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            run("./rebuild.sh")
        }
    end

    desc "upload", "Upload flatpak"
    def upload(*args)
        say "Upload flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            run("./upload.sh")
        }
    end

    desc "merge_develop", "Merge and push the kolabnow branch of the kube repository"
    def merge_develop(*args)
        say "Merging develop into kolabnow"
        Dir.chdir("#{Dir.home}/flatpak/tmp/kube") {
            run("git checkout develop")
            run("git pull")
            run("git checkout kolabnow")
            run("git merge develop -m 'Merged branch develop'")
            run("git push")
        }
    end

end

class Charles < Thor

    desc "foo ...", "Do some foo"
    def foo(*args)
        say "Do some foo"
        system("echo 'hi'")
    end

    desc "flatpak SUBCOMMAND ...", "Flatpak commands"
    subcommand "flatpak", Flatpak

end

Charles.start(ARGV)
