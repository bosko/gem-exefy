require "rubygems/command"
require "tmpdir"

module Gem
  module Commands
    class ExefyCommand < Gem::Command
      def initialize
        super 'exefy', "Replaces Gem's batch file with executable file (Windows only)"
        add_option('-b', '--backup-batch-files', 
               'Keep backup of old batch files') do |value, options|
          options[:backup_batch_files] = value
        end
      end

      def execute
        unless RUBY_PLATFORM =~ /mingw/
          say "This command can be executed only on Windows OS"
          return
        end

        get_all_gem_names.each do |name|
          begin
            cur_gem = Gem::Specification.find_by_name(name)
            batch_files(cur_gem).each do |k,v|
              generate_exe(k, v)
            end
          rescue Gem::LoadError => e
            say "Cannot exefy. Gem #{name} not found"
          end
        end
      end

      def batch_files(gem)
        bf = {}
        test_paths = Gem.path.map {|gp| File.join(gp, gem.bindir)}.unshift(Gem.bindir)
        gem.executables.each do |executable|
          test_paths.map {|tp| File.join(tp, "#{executable}.bat")}.each do |bat|
            bf[executable] = [] unless bf[executable]
            bf[executable] << bat if File.exist?(bat)
          end
        end
        bf
      end

      def generate_exe(executable, batch_files)
        log_message "Generating exe file"

        exefier_src_path = File.join(File.expand_path("../../../templates", __FILE__), "gem_exe.c")
        Dir.mktmpdir do |build_dir|
          # First create executable for all batch files (it is same .exe file but
          # batch files are found in different directories).
          targets = Hash[*['c', 'o', 'exe'].map { |ext| [ext, File.join(build_dir, "#{executable}.#{ext}")]}.flatten]
          FileUtils.cp exefier_src_path, targets["c"]
          compile(targets["c"], targets["o"])
          link(targets["o"], targets["exe"])

          batch_files.each do |bf|
            log_message "Copying exe file to #{File.dirname(bf)}..."
            FileUtils.cp targets["exe"], File.dirname(bf)
            if options[:backup_batch_files]
              log_message "Creating backup of old batch file"
              File.rename(bf, "#{bf}.bcp")
            else
              File.rm bf
            end
          end
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
