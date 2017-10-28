require 'open3'

module Commandline
    def run(cmd, &block)
        exit_status = Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
            output =  stdout.read.chomp
            if block_given?
                block.call(output)
            else
                puts output
            end
            thread.value
        end
        if exit_status != 0
            say "Nonzero exit code: ", exit_status
            raise "Command failed"
        end
    end

end
