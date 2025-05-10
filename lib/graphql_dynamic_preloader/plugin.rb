module GraphqlDynamicPreloader
  class Plugin
    def self.use(schema)
      schema.plugin(Plugin)
    end

    def initialize(schema)
      # Any setup needed
    end

    def before_multiplex(multiplex)
      preloader_context = GraphqlDynamicPreloader::Context.new
      multiplex.context[:graphql_dynamic_preloader] = preloader_context
    end

    def after_multiplex(multiplex)
      context = multiplex.context[:graphql_dynamic_preloader]
      context&.preload_all
    end
  end
end
