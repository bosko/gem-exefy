# coding: utf-8
# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/exefy/version'

Hoe.spec 'gem-exefy' do
  developer('Boško Ivanišević', 'bosko.ivanisevic@gmail.com')

  self.urls = {"GitHub repository" => "http://github.com/bosko/gem-exefy"}
  self.readme_file = 'README.rdoc'
  self.history_file = 'History.rdoc'
  self.extra_rdoc_files = FileList['*.rdoc']
  self.require_rubygems_version(">= 1.8.0")
  self.version = Exefy::VERSION
  spec_extras[:platform] = Gem::Platform::CURRENT
  spec_extras[:required_ruby_version] = ">= 1.9.3"
  self.post_install_message = %Q{**************************************************
*                                                *
*  Thank you for installing #{self.name}-#{self.version}!     *
*                                                *
*  This gem will work only on RubyInstaller      *
*  versions of Ruby with installed DevKit.       *
*                                                *
**************************************************}
end

# vim: syntax=ruby
