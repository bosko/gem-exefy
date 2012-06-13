require "rubygems/command_manager"

Gem::CommandManager.instance.register_command :exefy

Gem.pre_install do |installer|
  class << installer
    def generate_exe_file(filename, bindir)
      if RUBY_PLATFORM =~ /mingw/
        begin
          require 'exefy'

          exe_name = filename + ".exe"
          exe_path = File.join bindir, File.basename(exe_name)
          Exefy.process_gem_install(exe_path)

          say "Installed #{exe_path} executable" if Gem.configuration.really_verbose
        rescue LoadError
          puts "You must have DevKit installed in order to exefy gems"
          generate_batch_file(filename, bindir)
        end
      else
        generate_batch_file(filename, bindir)
      end
    end

    alias_method :generate_batch_file, :generate_windows_script
    alias_method :generate_windows_script, :generate_exe_file
  end
end

Gem.pre_uninstall do |uninstaller|
  class << uninstaller
    def remove_executables_and_exe_file(spec)
      return if spec.nil? or spec.executables.empty?

      list = Gem::Specification.find_all { |s|
        s.name == spec.name && s.version != spec.version
      }

      executables = spec.executables.clone

      list.each do |s|
        s.executables.each do |exe_name|
          executables.delete exe_name
        end
      end

      return if executables.empty?

      executables = executables.map { |exec| formatted_program_filename exec }

      remove = if @force_executables.nil? then
                 ask_yes_no("Remove executables:\n" \
                            "\t#{executables.join ', '}\n\n" \
                            "in addition to the gem?",
                            true)
               else
                 @force_executables
               end

      unless remove then
        say "Executables and scripts will remain installed."
      else
        bin_dir = @bin_dir || Gem.bindir(spec.base_dir)

        raise Gem::FilePermissionError, bin_dir unless File.writable? bin_dir

        executables.each do |exe_name|
          say "Removing #{exe_name}"

          exe_file = File.join bin_dir, exe_name

          FileUtils.rm_f exe_file
          batch_file = "#{exe_file}.bat"
          FileUtils.rm_f batch_file if File.exist?(batch_file)
          generic_exe = "#{exe_file}.exe"
          FileUtils.rm_f generic_exe if File.exist?(generic_exe)
        end
      end
    end

    alias_method :remove_executables_orig, :remove_executables
    alias_method :remove_executables, :remove_executables_and_exe_file
  end
end
