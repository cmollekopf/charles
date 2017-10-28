require 'test/unit'
require 'pry'
require 'charles/fileutils'

class Testfile
    def self.content
        <<~HEREDOC
        set(KDEPIM_VERSION_MINOR 13)
        set(KDEPIM_VERSION_PATCH 0)
        set(KDEPIM_VERSION_KOLAB 25)
        set(KDEPIM_VERSION ${KDEPIM_VERSION_MAJOR}.${KDEPIM_VERSION_MINOR}.${KDEPIM_VERSION_PATCH}.${KDEPIM_VERSION_KOLAB})

        configure_file(kdepim-version.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/kdepim-version.h @ONLY)
        HEREDOC
    end

    def self.create
        File.open("testfile", "w") do |f|
            f.write(content)
        end
    end

end

class MyTest < Test::Unit::TestCase
    def setup
        Testfile.create
    end

    # def teardown
    # end

    def test_fail
        Fileutils.replaceInFile("testfile", /VERSION_KOLAB (.*)\)/) { |s| (s.to_i + 5).to_s }
        lines = Fileutils.readlinesFromFile("testfile")
        assert(lines.grep(/VERSION_KOLAB 30\)/), 'Failed to find new version string.')
        assert_equal(6, lines.size)
    end
end
