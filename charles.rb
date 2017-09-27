#!/usr/bin/env ruby

require 'thor'

class Flatpak < Thor

    desc "rebuild", "Rebuild flatpak"
    def rebuild(*args)
        say "Rebuilding flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            system("./rebuild.sh")
        }
    end

    desc "upload", "Upload flatpak"
    def upload(*args)
        say "Upload flatpak"
        Dir.chdir("#{Dir.home}/flatpak/") {
            system("./upload.sh")
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
