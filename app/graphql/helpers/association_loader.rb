module Helpers
  module AssociationLoader
    extend T::Sig

    sig do
      params(
        name: T.any(String, Symbol),
        type: T.untyped,
        null: T::Boolean,
        options: T::Hash[Symbol, T.untyped],
        block: T.nilable(T.proc.void)
      ).void
    end
    def association_field(name, type:, null: true, **options, &block)
      field name, type, null: null, **options.merge(extras: [ :lookahead ]) do
        instance_eval(&block) if block
      end

      define_method(name) do |lookahead:, **args|
        context.dataloader
          .with(Loaders::AssociationDataloaderWithLookahead, name)
          .load_with_lookahead(object, lookahead)
      end
    end

    sig do
      params(
        name: T.any(String, Symbol),
        type: T.untyped,
        null: T::Boolean,
        max_page_size: T.nilable(Integer),
        scoped: T.nilable(
          T.proc.params(
            relation: ActiveRecord::Relation,
            args: T.untyped,
            context: T.untyped
          ).returns(ActiveRecord::Relation)
        ),
        options: T::Hash[Symbol, T.untyped],
        block: T.nilable(T.proc.void)
      ).void
    end
    def association_connection(name, type:, null: false, max_page_size: nil, scoped: nil, **options, &block)
      connection_class = GraphQL::Pagination::ActiveRecordRelationConnection

      field "#{name}_connection", type.connection_type, null: null, **options do
        instance_eval(&block) if block
      end

      define_method("#{name}_connection") do |**args|
        relation = object.public_send(name)
        relation = scoped.call(relation, args, context) if scoped

        connection = connection_class.new(relation, context: context, **args)
        connection.max_page_size = max_page_size if max_page_size
        connection
      end
    end
  end
end
