require 'exefy'
##
# Included during Gem.pre_install hook to override the installer object stub
# generation methods. 

module Exefy::StubOverride
  def generate_windows_script(filename, bindir)
    if Gem.win_platform? then
      exe_name = filename + ".exe"
      exe_path = File.join bindir, File.basename(exe_name)
      Exefy.process_gem_install(exe_path)

      say exe_path if Gem.configuration.really_verbose
    end
  end
end
