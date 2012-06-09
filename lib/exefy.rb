module Exefy
  require 'rubygems'
  require 'rubygems/user_interaction'
  require 'tmpdir'
  require 'devkit'

  def self.process_existing_gem(gem, options)
    generator = GeneratorFromBatch.new(gem, options)
    generator.exefy_gem
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

      gem_root = File.expand_path("../..", __FILE__)
      @executable = File.join(gem_root, "data", "gemstub.exe")
    end

    def generate_executable
      log_message "Generating executable '#{executable}'..."

      gem_root = File.expand_path("../..", __FILE__)
      template = File.join(gem_root, "templates", "gem_exe.c")

      Dir.mktmpdir do |build_dir|
        base = File.basename(template)
        obj  = File.join(build_dir, base.gsub(".c", ".o"))
        exe  = File.join(build_dir, base.gsub(".c", ".exe"))

        compile(template, obj)
        link(obj, exe)

        # verify target directory first exists
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

  class GeneratorFromBatch < Generator
    def initialize(gem, options)
      @gem = gem
      @options = options
    end

    def exefy_gem
      batch_files(@gem).each do |list|
        process(list)
      end
    end

    def process(batch_files)
      batch_files.each do |bf|
        target = bf.gsub(".bat", ".exe")
        install_executable_stub(target)

        if @options[:backup_batch_files]
          log_message "Creating backup of '#{File.basename(bf)}' batch file"
          File.rename(bf, "#{bf}.bcp")
        else
          log_message "Removing batch file '#{File.basename(bf)}'"
          File.unlink bf
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
      bf.values
    end
  end
end
