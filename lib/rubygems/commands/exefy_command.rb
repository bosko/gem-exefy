require "rubygems/command"
require "rbconfig"
require "tmpdir"

module Gem
  module Commands
    class ExefyCommand < Gem::Command
      def initialize
        super 'exefy', "Replaces Gem's batch file with executable file (RubyInstaller installation only)"
        add_option('-b', '--backup-batch-files', 
               'Keep backup of old batch files') do |value, options|
          options[:backup_batch_files] = value
        end
      end

      def execute
        begin
          require "devkit"
        rescue LoadError
          say "You must have DevKit installed in order to exefy gems"
          return
        end

        unless RUBY_PLATFORM =~ /mingw/
          say "This command can be executed only on RubyInstaller Windows OS installation"
          return
        end

        get_all_gem_names.each do |name|
          begin
            cur_gem = Gem::Specification.find_by_name(name)
            batch_files(cur_gem).each do |_, list|
              process(list)
            end
          rescue Gem::LoadError => e
            say "Cannot exefy. Gem #{name} not found"
          end
        end
      end

      def batch_files(gem)
        bf = {}
        test_paths = Gem.path.map {|gp| File.join(gp, gem.bindir)}.
                      unshift(Gem.bindir).uniq

        gem.executables.each do |executable|
          test_paths.map {|tp| File.join(tp, "#{executable}.bat")}.each do |bat|
            bf[executable] = [] unless bf[executable]
            bf[executable] << bat if File.exist?(bat)
          end
        end
        bf
      end

      def process(batch_files)
        unless File.executable?(executable)
          generate_executable
        end

        batch_files.each do |bf|
          target = bf.gsub(".bat", ".exe")

          log_message "Copying executable as '#{File.basename(target)}' file into #{File.dirname(bf)}..."
          FileUtils.install executable, target

          if options[:backup_batch_files]
            log_message "Creating backup of '#{File.basename(bf)}' batch file"
            File.rename(bf, "#{bf}.bcp")
          else
            log_message "Removing batch file '#{File.basename(bf)}'"
            File.unlink bf
          end
        end
      end

      def executable
        return @executable if defined?(@executable)

        gem_root = File.expand_path("../../../..", __FILE__)
        ruby_version = RbConfig::CONFIG["ruby_version"]
        @executable = File.join(gem_root, "data", ruby_version, "gemstub.exe")
      end

      def generate_executable
        log_message "Generating executable '#{executable}'..."

        gem_root = File.expand_path("../../../..", __FILE__)
        template = File.join(gem_root, "templates", "gem_exe.c")

        Dir.mktmpdir do |build_dir|
          base = File.basename(template)
          obj  = File.join(build_dir, base.gsub(".c", ".o"))
          exe  = File.join(build_dir, base.gsub(".c", ".exe"))

          compile(template, obj)
          link(obj, exe)

          # verify target directory exists first
          FileUtils.mkdir_p File.dirname(executable)

          FileUtils.install exe, executable
        end
      end

      def compile(source, target)
        cflags = RbConfig::CONFIG["CFLAGS"]
        cppflags = RbConfig::CONFIG["CPPFLAGS"]

        hdr_dir = RbConfig::CONFIG["rubyhdrdir"]
        arch_dir = RbConfig::CONFIG["arch"]

        include_dirs = "-I#{hdr_dir}/#{arch_dir} -I#{hdr_dir}"

        cc = ENV.fetch("CC", RbConfig::CONFIG["CC"])

        system "#{cc} -c #{source} -o #{target} #{cflags} #{cppflags} #{include_dirs}"
      end

      def link(objs, target)
        libruby_dir = RbConfig::CONFIG["libdir"]
        libruby = RbConfig::CONFIG["LIBRUBYARG"]

        libs = RbConfig::CONFIG["LIBS"]
        libs_dir = "-L#{libruby_dir} #{libruby} #{libs}"

        cc = ENV.fetch("CC", RbConfig::CONFIG["CC"])
        system "#{cc} #{objs} -o #{target} #{libs_dir}"
      end

      def log_message(message)
        say message if Gem.configuration.really_verbose
      end
    end
  end
end
