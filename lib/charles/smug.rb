require 'thor'
require 'oauth'
require 'json'

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
        smugconfig = YAML::load_file(File.join(__dir__, '../../config.yaml'))['smugmug']
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

