module Fileutils
    def self.readlinesFromFile(file)
        File.open(file, "r") do |f|
            f.readlines
        end
    end

    def self.replaceInFile(file, regex, &block)
        lines = []
        File.open(file, "r") do |f|
            lines = f.readlines
            index = lines.find_index{ |l| l.match?(regex) }
            line = lines[index]
            original = line[regex, 1]
            lines[index] = line.gsub(original, block.call(original))
        end
        File.open(file, "w") do |f|
            f.write(lines.join)
        end
    end
end

