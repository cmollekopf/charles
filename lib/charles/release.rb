require 'thor'
require 'json'
require 'crack'
require 'pry'
require 'awesome_print'
require_relative 'commandline'

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
            return "#{tag}.tar.gz"
        end

        def getLatestTag
            Commandline.run "git describe --tags --abbrev=0"
        end

        def commitFromTag(tag)
            Commandline.run "git log #{tag} -n 1 --pretty=format:'%H'"
        end

        def tagNewRelease(name)
            latestTag = getLatestTag()
            latestTagCommit = commitFromTag(latestTag)
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

        def updateDebianTarball(&block)
            Commandline.run "tar xzf debian.tar.gz"
            Dir.chdir("debian") {
                block.call
            }
            Commandline.run "tar czf debian.tar.gz debian"
            Commandline.run "rm -R debian"
        end

        def currentDirectoryName
            Dir.pwd.split('/').last
        end

    }

    desc "git", "Release a git repository from its source dir."
    def git(branch = "kolab/integration/4.13.0")
        say "Releasing #{currentDirectoryName} #{branch}"
        cleanCheckout(branch)
        tag = tagNewRelease(currentDirectoryName)

        Commandline.run "git push origin #{branch}:#{branch}"
        Commandline.run "git push origin #{tag}:#{tag}"
    end

    desc "obs", ""
    def obs(name)
        newVersion = ""
        patchVersion = 0
        Dir.chdir("#{Dir.home}/kdebuild/kdepim/source/#{name}") {
            latestTag = getLatestTag
            v = parseVersionNumber(latestTag)
            newVersion = "#{v[0]}.#{v[1]}.#{v[2]}.#{v[3]}"
            patchVersion = v[3]
            tarball = createReleaseTarball(latestTag)
            Commandline.run "mv #{tarball} #{Dir.home}/devel/obs/Kontact:4.13:Development/#{name}/#{tarball.gsub("-", "_").gsub("tar.gz", "orig.tar.gz")}"
        }
        Dir.chdir("#{Dir.home}/devel/obs/Kontact:4.13:Development/#{name}") {
            Commandline.run "osc up"
            Commandline.run "osc revert ."
            Fileutils.replaceInFile("#{name}.spec", /define patch_version (.*)$/) { patchVersion.to_s }
            #TODO insert lines after %changelog
            Dir.glob("#{name}*.dsc").each do |file|
                Fileutils.replaceInFile(file, /4\.13\.0\.(.*)$/) { patchVersion.to_s }
            end

            if File.file? "debian.changelog"
                Fileutils.prependToFile("debian.changelog", <<~HEREDOC)
                    #{name} (4:#{newVersion}-0~kolab1) unstable; urgency=medium

                    * New upstream release #{newVersion}

                    -- Christian Mollekopf (Kolab Systems) <mollekopf@kolabsystems.com>  #{DateTime.now.strftime('%a, %d %b %Y %k:%M:%S %z')}

                HEREDOC
            else
                updateDebianTarball {
                    Fileutils.prependToFile("changelog", <<~HEREDOC)
                        #{name} (4:#{newVersion}-0~kolab1) unstable; urgency=medium

                        * New upstream release #{newVersion}

                        -- Christian Mollekopf (Kolab Systems) <mollekopf@kolabsystems.com>  #{DateTime.now.strftime('%a, %d %b %Y %k:%M:%S %z')}

                    HEREDOC
                }
            end

            tarballs = Dir.glob("*orig.tar.gz").sort
            Commandline.run "osc delete #{tarballs[0]}"
            Commandline.run "osc add #{tarballs[1]}"
            Commandline.run "osc ci -m 'New release'"
        }
    end

    desc "obs_status", ""
    def obs_status
        projects = ["Kontact:4.13:Development", "Kontact:4.13"]
        repos = ["Fedora_26"]
        projects.each do |project|
            Commandline.run "osc prjresults #{project} -r #{repos.join(',')} --xml" do |s|
                hash = Crack::XML.parse(s)
                results = hash["resultlist"]["result"]
                if repos.count > 1
                    result = results
                        .select { |r| repos.include? r["repository"] }
                        .map do |r|
                            {
                                :project => r["project"],
                                :repository => r["repository"],
                                :state => r["state"],
                                :status => r["status"].select { |s| not ["disabled", "succeeded", "excluded"].include? s["code"]  }
                            }
                        end
                else
                    r = results
                    result = {
                        :project => r["project"],
                        :repository => r["repository"],
                        :state => r["state"],
                        :status => r["status"].select { |s| not ["disabled", "succeeded", "excluded"].include? s["code"]  }
                    }
                end
                ap result, {:index => false}
            end
        end
    end

    desc "obs_merge", "Merge a repository to stable"
    def obs_merge(repository)
        Commandline.run "osc request list -M Kontact:4.13" do |output|
            unless output.include? "No results"
                say "There already are pending requests, cleanup first"
                exit
            end
        end
        Commandline.run "osc sr Kontact:4.13:Development #{repository} Kontact:4.13 -m 'Merge please'"
        Commandline.run "osc request list -M Kontact:4.13" do |output|
            requestNumber = output.split(' ').first
            Commandline.run "osc request show -ud #{requestNumber}"
            if yes? "Accept?"
                Commandline.run "osc request accept #{requestNumber} -m 'Accepted'"
            end
        end
    end



end

