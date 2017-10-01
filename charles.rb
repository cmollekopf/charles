#!/usr/bin/env ruby

require 'thor'
require 'icalendar'
require 'net/http'
require 'yaml'
require 'chronic'

class Time
    def addHours(hours)
        self + (hours * 60 * 60)
    end
end

def run(cmd)
    #Exit if a command fails
    system(cmd) or exit
end

class Dav < Thor
    desc "event", "Schedule an event"
    def event(*args)

        subject = args[0]
        timeString = args[1..-1].join(' ')
        startDate = Chronic.parse(timeString)
        say "Scheduling a new event for "
        say "Subject: " + subject
        say "Date: " + startDate.strftime('%m/%d/%Y %H:%M')

        cal = Icalendar::Calendar.new
        cal.event do |e|
            e.dtstart = startDate
            e.dtend = startDate.addHours(1)
            e.summary = subject
        end

        cal_string = cal.to_ical

        config = YAML::load_file('./config.yaml')
        caldavconfig = config['caldav']

        user = caldavconfig['user']
        password=caldavconfig['password']
        host=caldavconfig['host']
        calendar=caldavconfig['calendar']
        path='/calendars/' + user + '/' + calendar + '/newevent.ics'

        say path
        uri = URI.join(URI.escape(host + path))
        req = Net::HTTP::Put.new(uri)
        req.set_content_type('text/calendar', {'charset' => 'utf-8'})
        # req['If-None-Match'] = '*'
        req.body = cal_string

        req.basic_auth(user, password)

        res = Net::HTTP.start(uri.hostname, uri.port, {:use_ssl => uri.scheme == "https"}) do |http|
            http.set_debug_output $stderr
            say "Posting request"
            http.request(req)
        end

        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
            # OK
            say "Request succeeded: " + res.body
        else
            say "Request failed: " + res.msg
            say "Request failed: " + res.body
        end
        say "Done"
    end
    default_task :event

end

class Flatpak < Thor

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



class Charles < Thor

    desc "foo", "Do some foo"
    def foo
        say "Do some foo"
        system("echo 'hi'")
    end

    desc "flatpak SUBCOMMAND ...", "Flatpak commands"
    subcommand "flatpak", Flatpak

    desc "schedule SUBCOMMAND ...", "Scheduling commands"
    subcommand "schedule", Dav

    desc "sshtunnel", "Open ssh tunnel."
    def sshtunnel
        say "Opening ssh tunnel"
        system "autossh -f -N -M 6565 tunnel"
    end

end

Charles.start(ARGV)
