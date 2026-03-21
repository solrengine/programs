require "rails/generators"

module Solrengine
  module Generators
    class ProgramGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :program_name, type: :string, desc: "Program name (e.g., PiggyBank)"
      argument :idl_path, type: :string, desc: "Path to Anchor IDL JSON file"

      def parse_idl
        unless File.exist?(idl_path)
          raise Thor::Error, "IDL file not found: #{idl_path}"
        end

        @idl = Solrengine::Programs::IdlParser.parse_file(idl_path)
        say "Parsed IDL: #{@idl.name} (#{@idl.instructions.size} instructions, #{@idl.accounts.size} accounts)"
      end

      def copy_idl
        destination = "config/idl/#{program_snake}.json"
        if File.exist?(File.join(destination_root, destination))
          say_skipped(destination)
        else
          copy_file idl_path, destination
        end
      end

      def create_account_models
        @idl.accounts.each do |account|
          destination = "app/models/#{program_snake}/#{account.name.underscore}.rb"
          if File.exist?(File.join(destination_root, destination))
            say_skipped(destination)
          else
            @account = account
            @program_id = @idl.program_id
            template "account.rb.erb", destination
          end
        end
      end

      def create_instruction_builders
        @idl.instructions.each do |instruction|
          destination = "app/services/#{program_snake}/#{instruction.name}_instruction.rb"
          if File.exist?(File.join(destination_root, destination))
            say_skipped(destination)
          else
            @instruction = instruction
            @program_id = @idl.program_id
            template "instruction.rb.erb", destination
          end
        end
      end

      def create_stimulus_controller
        destination = "app/javascript/controllers/#{program_snake}_controller.js"
        if File.exist?(File.join(destination_root, destination))
          say_skipped(destination)
        else
          @idl_instance = @idl
          template "stimulus_controller.js.erb", destination
        end
      end

      def show_summary
        say ""
        say "Program '#{program_class}' generated successfully!", :green
        say ""
        say "Generated files:"
        say "  config/idl/#{program_snake}.json"
        @idl.accounts.each do |acct|
          say "  app/models/#{program_snake}/#{acct.name.underscore}.rb"
        end
        @idl.instructions.each do |ix|
          say "  app/services/#{program_snake}/#{ix.name}_instruction.rb"
        end
        say "  app/javascript/controllers/#{program_snake}_controller.js"
        say ""
        say "Next steps:"
        say "  1. Add custom query methods to your account models"
        say "  2. Register the Stimulus controller in your index.js"
        say "  3. Create Rails controller endpoints for instruction building"
      end

      private

      def program_class
        program_name.camelize
      end

      def program_snake
        program_name.underscore
      end

      def say_skipped(path)
        say "  skip  #{path} (already exists)", :yellow
        say "        Re-run with different name or manually update the file"
      end
    end
  end
end
