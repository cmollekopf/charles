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

class Dav < Thor
    desc "event SUBJECT DATE ", "Schedule an event: "
    def event(subject, *args)
        timeString = args.join(' ')
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

        config = YAML::load_file(File.join(__dir__, '../../config.yaml'))
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
