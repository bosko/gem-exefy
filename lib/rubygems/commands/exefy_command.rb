require "rubygems/command"

module Gem
  module Commands
    class ExefyCommand < Gem::Command
      def initialize
        super 'exefy', "Replaces Gem's batch file with executable file (RubyInstaller installation only)"

        add_option('--all', 'Replaces batch files with executable file',
               'for all installed gems') do |value, options|
          options[:process_all_gems] = value
        end

        add_option('--revert', 'Restores batch files for given gem',
               'or all gems if --all option is used') do |value, options|
          options[:revert] = value
        end
      end

      def arguments
        "GEMNAME       name of gem to exefy (unless --all)"
      end

      def usage # :nodoc:
        "#{program_name} [args]"
      end

      def description # :nodoc:
        <<-EOS
The exefy command replaces the default gem batch(.bat) script runner with
an Windows executable(.exe) stub. Exefy also includes hooks that will
automatically do this for all new Gem installs and will remove the executable
with a Gem uninstall.
Requires a RubyInstaller Ruby installation and the RubyInstaller DevKit.
        EOS
      end

      def execute
        unless RUBY_PLATFORM =~ /mingw/
          say "This command can be executed only on RubyInstaller Windows OS installation"
          return
        end

        begin
          require "devkit" unless options[:revert]
          require "exefy"
        rescue ::LoadError => load_error
          say "You must have DevKit installed in order to exefy gems"
          return
        end

        gem_specs = if options[:process_all_gems] then
                      Gem::Specification
                    else
                      begin
                        gem_name = get_one_gem_name
                        Gem::Specification.find_all_by_name(gem_name)
                      rescue Gem::LoadError => e
                        say "Cannot exefy. Gem #{name} not found"
                      end
                    end

        gem_specs.each do |gem_spec|
          Exefy.process_existing_gem(gem_spec, options[:revert])
        end
      end
    end
  end
end
