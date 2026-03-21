require "solrengine/rpc"
require "borsh"

module Solrengine
  module Programs
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class DeserializationError < Error; end
    class TransactionError < Error; end
    class ProgramError < Error
      attr_reader :code, :error_name

      def initialize(code:, error_name:, message:)
        @code = code
        @error_name = error_name
        super("#{error_name} (#{code}): #{message}")
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end
    end
  end
end

require_relative "programs/version"
require_relative "programs/configuration"
require_relative "programs/borsh_types"
require_relative "programs/idl_parser"
require_relative "programs/pda"
require_relative "programs/error_mapper"
require_relative "programs/account"
require_relative "programs/instruction"
require_relative "programs/transaction_builder"
require_relative "programs/engine" if defined?(Rails::Engine)
