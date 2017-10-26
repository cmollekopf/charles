#!/usr/bin/env ruby

require 'thor'
require 'icalendar'
require 'net/http'
require 'yaml'
require 'chronic'
require 'oauth'
require 'json'
require 'pry'

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
        if !startDate
            say "Failed to parse date: " + timeString
            say "Example date: 25/10 at 19:00"
            return
        end
        say "Scheduling a new event for "
        say "Subject: " + subject

        cal = Icalendar::Calendar.new
        cal.event do |e|
            e.dtstart = startDate
            e.dtend = startDate.addHours(1)
            e.summary = subject
        end

        config = YAML::load_file('./config.yaml')
        caldavconfig = config['caldav']

        user = caldavconfig['user']
        password = caldavconfig['password']
        host = caldavconfig['host']
        calendar = caldavconfig['calendar']
        path ='/calendars/' + user + '/' + calendar + '/newevent.ics'

        say path
        uri = URI.join(URI.escape(host + path))
        req = Net::HTTP::Put.new(uri)
        req.set_content_type('text/calendar', {'charset' => 'utf-8'})
        # req['If-None-Match'] = '*'
        req.body = cal.to_ical

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

class Smug < Thor

    no_commands {

    def requestAccessToken(oauth_verifier)
        access_token = @request_token.get_access_token(:oauth_verifier => oauth_verifier)
        puts "Response:"
        access_token.params.each do |k,v|
            puts "  #{k}: #{v}" unless k.is_a?(Symbol)
        end

        say "Secret: " + access_token.secret
        say "Token: " + access_token.token
        return access_token
    end

    def getAccessToken(consumer)
        tokenStoreFile = File.join(__dir__, 'oauthAccessToken.yaml')
        if File.file?(tokenStoreFile)
            File.open(tokenStoreFile) do |f|
                tokenStore = YAML::load(f)
                # TODO validate token?
                return OAuth::AccessToken.new(consumer, tokenStore['token'], tokenStore['secret'])
            end
        end

        @request_token = consumer.get_request_token
        say "Visit the following url to login: " + @request_token.authorize_url({'showSignUpButton' => false})
        say "Please enter the received pin:"
        oauth_verifier = $stdin.gets.chomp
        token = requestAccessToken(oauth_verifier)
        File.open(tokenStoreFile, 'w') do |out|
            YAML.dump({'secret' => token.secret, 'token' => token.token}, out)
        end
        return token
    end

    def oauthLogin(key, secret)
        @consumer = OAuth::Consumer.new(key, secret, {
            :site               => "https://api.smugmug.com",
            :scheme             => :header,
            :http_method        => :post,
            :request_token_path => "/services/oauth/1.0a/getRequestToken",
            :access_token_path  => "/services/oauth/1.0a/getAccessToken",
            :authorize_path     => "/services/oauth/1.0a/authorize"
        })
        return getAccessToken(@consumer)
    end

    def apiToken()
        smugconfig = YAML::load_file(File.join(__dir__, 'config.yaml'))['smugmug']
        return oauthLogin(smugconfig['APIKey'], smugconfig['APISecret'])
    end

    def printResult(result)
        case result
        when Net::HTTPRedirection
            say "Redirected: " + result['location']
            say "Body: " + result.body + result.code
        when Net::HTTPSuccess, Net::HTTPRedirection
            say "Request succeeded: " + result.body
        else
            say "Request failed: " + result.body
        end
    end

    def get(token, uri)
        result = token.get(uri, {'Accept' => 'application/json'})
        case result
        when Net::HTTPRedirection
            say "Redirected: " + result['location']
            say "Body: " + result.body + result.code
        when Net::HTTPSuccess, Net::HTTPRedirection
            return JSON.parse(result.body)
        else
            say "Request failed: " + result.body
        end
    end

    }

    desc "list", "List albums"
    def list(*args)
        token = apiToken
        rootNodeUri = get(token, '/api/v2/user/cmollekopf')['Response']['User']['Uris']['Node']['Uri']
        result = get(token, rootNodeUri + '!children')
        albums = result["Response"]["Node"].map{|x| {:name => x["Name"], :uri=> x["Uri"], :url => x["WebUri"]}}
        say albums.map{|x| x[:name] + ": " + x[:url]}.join "\n"

        binding.pry
    end

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

    desc "smug SUBCOMMAND ...", "SmugMug commands"
    subcommand "smug", Smug

    desc "sshtunnel", "Open ssh tunnel."
    def sshtunnel
        say "Opening ssh tunnel"
        system "autossh -f -N -M 6565 tunnel"
    end

end

Charles.start(ARGV)
