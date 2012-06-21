module Exefy
  require 'rubygems'
  require 'rubygems/user_interaction'
  require 'tmpdir'
  require 'rbconfig'
  require 'erb'
  require 'version'

  def self.process_existing_gem(gem, revert)
    generator = GeneratorFromBatch.new(gem)
    revert ? generator.revert_gem : generator.exefy_gem
  end

  def self.process_gem_install(target_path)
    generator = Generator.new(target_path)
    generator.exefy_gem
  end

  class Generator
    include Gem::UserInteraction

    def initialize(target_path)
      @exe_target = target_path
    end

    def exefy_gem
      process
    end

    def process
      install_executable_stub(@exe_target)
    end

    def install_executable_stub(target)
      unless File.executable?(executable)
        generate_executable
      end

      log_message "Creating executable as '#{File.basename(target)}'"
      FileUtils.install executable, target
    end

    def executable
      return @executable if defined?(@executable)

      gem_root     = File.expand_path("../..", __FILE__)
      ruby_version = RbConfig::CONFIG["ruby_version"]

      @executable = File.join(gem_root, "data", ruby_version, "gemstub.exe")
    end

    def generate_executable
      log_message "Generating executable '#{executable}'..."

      gem_root = File.expand_path("../..", __FILE__)
      template = File.join(gem_root, "templates", "gem_exe.c")
      res_template = File.join(gem_root, "templates", "gem_exe.rc.erb")

      Dir.mktmpdir do |build_dir|
        base = File.basename(template)
        res_base = File.basename(res_template)

        obj  = File.join(build_dir, base.gsub(".c", ".o"))
        res_src = File.join(build_dir, res_base.gsub(".erb", ""))
        res_obj = File.join(build_dir, res_base.gsub(".erb", ".o"))
        exe  = File.join(build_dir, base.gsub(".c", ".exe"))

        compile(template, obj)
        compile_resources(res_template, res_src, res_obj)
        link([obj, res_obj].join(" "), exe)

        # verify target directory first exists
        FileUtils.mkdir_p File.dirname(executable)

        FileUtils.install exe, executable
      end
    end

    def compile(source, target)
      cflags = RbConfig::CONFIG["CFLAGS"]
      cppflags = RbConfig::CONFIG["CPPFLAGS"]

      hdr_dir = RbConfig::CONFIG["rubyhdrdir"] || RbConfig::CONFIG["includedir"]
      arch_dir = RbConfig::CONFIG["arch"]

      include_dirs = "-I#{hdr_dir}/#{arch_dir} -I#{hdr_dir}"

      cc = ENV.fetch("CC", RbConfig::CONFIG["CC"])

      system "#{cc} -c #{source} -o #{target} #{cflags} #{cppflags} #{include_dirs}"
    end

    def compile_resources(template, source, target)
      ruby_version = RbConfig::CONFIG["ruby_version"]
      binary_version = VERSION.gsub('.', ',') + ",0"
      File.open source, "w" do |file|
        erb = ERB.new File.read(template)
        file.puts erb.result(binding)
      end

      system "windres #{source} -o #{target}"
    end

    def link(objs, target)
      libruby_dir = RbConfig::CONFIG["libdir"]
      libruby = RbConfig::CONFIG["LIBRUBYARG"]

      libs = RbConfig::CONFIG["LIBS"]
      libs_dir = "-L#{libruby_dir} #{libruby} #{libs}"

      cc = ENV.fetch("CC", RbConfig::CONFIG["CC"])
      system "#{cc} #{objs} -o #{target} #{libs_dir}"
      system "strip #{target}"
    end

    def log_message(message)
      say message if Gem.configuration.really_verbose
    end
  end

  class GeneratorFromBatch < Generator
    def initialize(gem)
      @gem = gem
    end

    def exefy_gem
      batch_files(@gem).each do |list|
        process(list)
      end
    end

    def revert_gem
      require "rubygems/installer"

      return if @gem.executables.nil? or @gem.executables.empty?

      # Instantiate Gem::Installer object with no additional options
      # WARNING!!! at the moment RubyGems do not handle additional
      # install options correctly (--install-dir or --bindir). Once
      # gem is installed in non-default location it becomes unusable.
      # We cannot get path to its .bat files nor path where it is
      # installed (https://github.com/rubygems/rubygems/issues/342).
      # Therefore we will, for now, process gems as they are always
      # installed in default locations.
      @gem.executables.each do |filename|
        filename.untaint
        exe_file = File.join(Gem.bindir, "#{filename}.exe")
        if File.exist? exe_file
          Gem::Installer.new(@gem).generate_windows_script(filename, Gem.bindir)
          if File.exist? exe_file.gsub(".exe", ".bat")
            log_message "Removing #{exe_file}"
            File.unlink exe_file
          else
            log_message "Reverting batch file failed. Executable file will remain in bin directory."
          end
        end
      end
    end

    def process(batch_files)
      batch_files.each do |bf|
        target = bf.gsub(".bat", ".exe")
        install_executable_stub(target)

        log_message "Removing batch file '#{File.basename(bf)}'"
        File.unlink bf
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
      bf.values
    end
  end
end
