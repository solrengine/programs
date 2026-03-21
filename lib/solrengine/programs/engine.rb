module Solrengine
  module Programs
    class Engine < ::Rails::Engine
      isolate_namespace Solrengine::Programs

      initializer "solrengine-programs.assets" do |app|
        app.config.assets.paths << root.join("app/assets/javascripts")
      end
    end
  end
end
