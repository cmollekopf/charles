require 'thor'
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

    desc "obs_kdepim", ""
    def obs_kdepim
        name = "kdepim"
        newVersion = ""
        Dir.chdir("#{Dir.home}/kdebuild/kdepim/source/#{name}") {
            latestTag = getLatestTag
            v = parseVersionNumber(latestTag)
            newVersion = "#{v[0]}.#{v[1]}.#{v[2]}.#{v[3]}"
            tarball = createReleaseTarball(latestTag)
            Commandline.run "mv #{tarball} #{Dir.home}/devel/obs/Kontact:4.13:Development/#{name}/#{tarball.gsub("-", "_").gsub("tar.gz", "orig.tar.gz")}"
        }
        Dir.chdir("#{Dir.home}/devel/obs/Kontact:4.13:Development/#{name}") {
            Commandline.run "osc up"
            Commandline.run "osc revert ."
            Fileutils.replaceInFile("kdepim.spec", /define patch_version (.*)$/) { |s| (s.to_i + 1).to_s }
            #TODO insert lines after %changelog
            regexp = /really4\.13\.0\.(.*)-0~kolab1$/
            Fileutils.replaceInFile("kdepim-Ubuntu_14.04.dsc", regexp) { |s| (s.to_i + 1).to_s }
            Fileutils.replaceInFile("kdepim-Ubuntu_16.04.dsc", regexp) { |s| (s.to_i + 1).to_s }

            updateDebianTarball {
                Fileutils.prependToFile("changelog", <<~HEREDOC)
                    kdepim (4:#{newVersion}-0~kolab1) unstable; urgency=medium

                      * New upstream release #{newVersion}

                     -- Christian Mollekopf (Kolab Systems) <mollekopf@kolabsystems.com>  #{DateTime.now.strftime('%a, %d %b %Y %k:%M:%S %z')}

                HEREDOC
            }

            tarballs = Commandline.run("ls *.tar.gz").split("\n")
            Commandline.run "osc delete #{tarballs[0]}"
            Commandline.run "osc add #{tarballs[1]}"
            Commandline.run "osc ci -m 'New release'"
        }
    end
end
