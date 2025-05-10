module Helpers
  module AssociationLoader
    def association_field(name, type:, null: false, **options)
      field name, type, null: null, **options.merge(extras: [ :lookahead ])

      define_method(name) do |lookahead:|
        context
          .dataloader
          .with(Loaders::AssociationDataloaderWithLookahead, name, lookahead)
          .load(object)
      end
    end
  end
end
