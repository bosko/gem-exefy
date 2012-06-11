require "rubygems/command_manager"

Gem::CommandManager.instance.register_command :exefy

Gem.pre_install do |installer|
  class << installer
    self.class_eval  do
      define_method :generate_exe_file do |filename, bindir|
        if RUBY_PLATFORM =~ /mingw/
          require 'exefy'
          exe_name = filename + ".exe"
          exe_path = File.join bindir, File.basename(exe_name)
          Exefy.process_gem_install(exe_path)

          say "Installed #{exe_path} executable" if Gem.configuration.really_verbose
        else
          generate_batch_file(filename, bindir)
        end
      end
    end

    alias_method :generate_batch_file, :generate_windows_script
    alias_method :generate_windows_script, :generate_exe_file
  end
end
