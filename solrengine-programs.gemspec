require_relative "lib/solrengine/programs/version"

Gem::Specification.new do |spec|
  spec.name = "solrengine-programs"
  spec.version = Solrengine::Programs::VERSION
  spec.authors = [ "Jose Ferrer" ]
  spec.email = [ "estoy@moviendo.me" ]

  spec.summary = "Solana program interaction for Rails via Anchor IDL parsing"
  spec.description = "Parse Anchor IDL files to scaffold Ruby account models, instruction builders, and Stimulus controllers for interacting with custom Solana programs."
  spec.homepage = "https://github.com/solrengine/programs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "LICENSE", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "solrengine-rpc", "~> 0.1"
  spec.add_dependency "borsh", "~> 0.2"
  spec.add_dependency "ed25519", "~> 1.3"
  spec.add_dependency "base58", "~> 0.2"
end
