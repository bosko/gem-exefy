require "rubygems/command_manager"
require 'exefy'
require 'exefy/gem_install_stub'

Gem::CommandManager.instance.register_command :exefy

Gem.pre_install do |installer|
  installer.extend(Exefy::StubOverride)
end
