require 'open3'

module Commandline
    def self.run(cmd, &block)
        output = ""
        exit_status = Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
            output = stdout.read.chomp
            if block_given?
                block.call(output)
            else
                puts output
            end
            thread.value
        end
        if exit_status != 0
            puts "Nonzero exit code: ", exit_status, "Command: ", cmd
            raise "Command failed"
        end
        return output
    end

end
