module Solrengine
  module Programs
    class ErrorMapper
      ANCHOR_ERROR_OFFSET = 6000

      def initialize(parsed_errors)
        @errors_by_code = parsed_errors.each_with_object({}) do |err, h|
          h[err.code] = err
        end
      end

      def map(error_code)
        err = @errors_by_code[error_code]
        return nil unless err

        { code: err.code, name: err.name, message: err.message }
      end

      # Extract custom error code from an RPC InstructionError response
      # Example: {"InstructionError":[0,{"Custom":6001}]}
      def self.extract_custom_error(rpc_error)
        return nil unless rpc_error.is_a?(Hash)

        instruction_error = rpc_error["InstructionError"]
        return nil unless instruction_error.is_a?(Array) && instruction_error.size == 2

        custom = instruction_error[1]
        return nil unless custom.is_a?(Hash) && custom.key?("Custom")

        custom["Custom"]
      end

      def raise_if_program_error!(rpc_error)
        code = self.class.extract_custom_error(rpc_error)
        return unless code

        mapped = map(code)
        if mapped
          raise ProgramError.new(
            code: mapped[:code],
            error_name: mapped[:name],
            message: mapped[:message]
          )
        else
          raise TransactionError, "Program error with unknown code: #{code}"
        end
      end
    end
  end
end
