require "rubygems/command_manager"

Gem::CommandManager.instance.register_command :exefy

Gem.pre_install do |installer|
  require 'exefy'
  require 'exefy/gem_install_stub'
  installer.extend(Exefy::StubOverride)
end
