require "json"

module Solrengine
  module Programs
    class IdlParser
      class UnsupportedVersionError < Error; end

      SUPPORTED_SPEC = "0.1.0"

      ParsedIdl = Struct.new(
        :program_id, :name, :version, :instructions, :accounts, :types, :errors,
        keyword_init: true
      )

      ParsedInstruction = Struct.new(
        :name, :discriminator, :accounts, :args,
        keyword_init: true
      )

      ParsedAccount = Struct.new(
        :name, :discriminator, :fields,
        keyword_init: true
      )

      ParsedType = Struct.new(
        :name, :kind, :fields,
        keyword_init: true
      )

      ParsedField = Struct.new(
        :name, :type,
        keyword_init: true
      )

      ParsedAccountMeta = Struct.new(
        :name, :writable, :signer, :address, :relations,
        keyword_init: true
      )

      ParsedError = Struct.new(
        :code, :name, :message,
        keyword_init: true
      )

      def self.parse(json_string)
        new(json_string).parse
      end

      def self.parse_file(path)
        parse(File.read(path))
      end

      def initialize(json_string)
        @data = JSON.parse(json_string)
      end

      def parse
        validate_spec_version!

        ParsedIdl.new(
          program_id: @data["address"],
          name: @data.dig("metadata", "name"),
          version: @data.dig("metadata", "version"),
          instructions: parse_instructions,
          accounts: parse_accounts,
          types: parse_types,
          errors: parse_errors
        )
      end

      private

      def validate_spec_version!
        spec = @data.dig("metadata", "spec")
        unless spec == SUPPORTED_SPEC
          raise UnsupportedVersionError,
            "Unsupported Anchor IDL spec version '#{spec}'. Expected '#{SUPPORTED_SPEC}'."
        end
      end

      def parse_instructions
        (@data["instructions"] || []).map do |ix|
          ParsedInstruction.new(
            name: ix["name"],
            discriminator: ix["discriminator"]&.pack("C*"),
            accounts: parse_account_metas(ix["accounts"] || []),
            args: parse_fields(ix["args"] || [])
          )
        end
      end

      def parse_accounts
        types_by_name = (@data["types"] || []).each_with_object({}) do |t, h|
          h[t["name"]] = t
        end

        (@data["accounts"] || []).map do |acct|
          type_def = types_by_name[acct["name"]]
          fields = type_def ? parse_fields(type_def.dig("type", "fields") || []) : []

          ParsedAccount.new(
            name: acct["name"],
            discriminator: acct["discriminator"]&.pack("C*"),
            fields: fields
          )
        end
      end

      def parse_types
        (@data["types"] || []).map do |t|
          ParsedType.new(
            name: t["name"],
            kind: t.dig("type", "kind"),
            fields: parse_fields(t.dig("type", "fields") || [])
          )
        end
      end

      def parse_errors
        (@data["errors"] || []).map do |err|
          ParsedError.new(
            code: err["code"],
            name: err["name"],
            message: err["msg"]
          )
        end
      end

      def parse_fields(fields)
        fields.map do |f|
          ParsedField.new(
            name: f["name"],
            type: f["type"]
          )
        end
      end

      def parse_account_metas(accounts)
        accounts.map do |acct|
          ParsedAccountMeta.new(
            name: acct["name"],
            writable: acct["writable"] || false,
            signer: acct["signer"] || false,
            address: acct["address"],
            relations: acct["relations"]
          )
        end
      end
    end
  end
end
