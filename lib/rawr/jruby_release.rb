require 'open-uri'
require 'fileutils'

module Rawr
  class JRubyRelease
    @@releases = nil

    BASE_URL='http://repo1.maven.org/maven2/org/jruby/jruby-complete'

    attr_accessor :version, :rc, :version_string

    def self.get(version, destination)
      release = case version
                when 'current'
                  get_most_current_releases(1).first
                when 'stable'
                  get_most_current_stable_releases(1).first
                end
      release.download
      release.move_to destination
    end

    def self.get_most_current_releases(count=5)
      @@releases ||= get_list
      if @@releases.size > count
        return [@@releases.last] if count == 1
        @@releases[(@@releases.size-(count+1))..(@@releases.size-1)]
      else
        @@releases
      end
    end

    def self.get_most_current_stable_releases(count=5)
      @@releases ||= get_list
      selected = @@releases.select{ |r| r.rc.to_s.strip.empty? }
      if selected .size > count
        return [selected.last] if count == 1
        selected[(selected.size-(count+1))..(selected.size-1)]
      else
        selected
      end
    end

    def self.get_list
      # We get HTML 3.2 or something, with lines like this:
      # <a href="0.9.8/">
      #
      # so we want to find all of those and find the latest, but note any RC entries
      lines = open(BASE_URL).readlines
      lines.map!{|l| l =~ /(href=")([\.\d]+)(\/">)/ ? $2 : nil }
      lines.compact!
      lines.map!{|l| new(l) }
      lines.sort!

      @@releases = lines
    end

    def initialize(version_string)
      @version_string = version_string
      version_string =~ /([\.\d]+)(RC\d)*/
      @version = $1.to_s
      @rc = $2.to_s
      mj,mn,patch = @version.split('.')
      @version  = "#{mj.to_i}.#{mn.to_i}.#{patch.to_i}"
    end

    def download
      File.open("jruby-complete.jar","wb") do |f|
        f.write(open(jar_url).read)
      end
    end

    def move_to(destination)
      FileUtils.mkdir_p destination
      FileUtils.move("jruby-complete.jar", "#{destination}/jruby-complete.jar")
    end

    def jar_url
      # http://repository.codehaus.org/org/jruby/jruby-complete/1.1RC2/jruby-complete-1.1RC2.jar
      # http://repository.codehaus.org/org/jruby/jruby-complete/1.1.4/jruby-complete-1.1.4.jar
      # For example.
      "#{BASE_URL}/#{@version_string}/jruby-complete-#{@version_string}.jar"
    end

    def <=>(other)
      raise "#{other} is not a Release." unless other.kind_of?(Rawr::JRubyRelease)
      sv = self.version.split('.').map { |s| s.to_i }
      ov = other.version.split('.').map { |s| s.to_i }
      return self.version <=> other.version unless sv.size == ov.size
      0.upto(sv.size - 2) { |n| return sv[n] <=> ov[n] unless sv[n] == ov[n] }
      sv[-1] <=> ov[-1]
    end

    def to_s
      "<Release @version=#{@version}; @rc='#{@rc}' jar_url='#{jar_url}'/>"
    end

    def to_nice_string
      "Release version #{@version} #{@rc} #{jar_url}"
    end

    def full_version_string
      "#{@version} #{@rc}"
    end
  end
end
