module Helpers
  module AssociationLoader
    extend T::Sig

    # Defines a GraphQL field that loads an ActiveRecord association using a lookahead-aware dataloader.
    sig do
      params(
        # The name of the association to expose as a field (e.g., :comments)
        name: T.any(String, Symbol),

        # The GraphQL type for the field (e.g., Types::CommentType)
        type: T.untyped,

        # Whether the field is nullable
        null: T::Boolean,

        # Additional GraphQL field options (e.g., :description, :method)
        options: T::Hash[Symbol, T.untyped],

        # Optional block to define arguments or extensions for the field
        block: T.nilable(T.proc.void)
      ).void
    end
    def association_field(name, type:, null: true, **options, &block)
      # Declare the GraphQL field and inject lookahead as a resolver extra.
      field name, type, null: null, **options.merge(extras: [ :lookahead ]) do
        instance_eval(&block) if block
      end

      # Define a method to resolve the field using the dataloader with lookahead.
      define_method(name) do |lookahead:, **args|
        # Enqueue the association to be preloaded using the dataloader, passing
        # the current object and lookahead.
        context.dataloader
          .with(Loaders::AssociationDataloaderWithLookahead, name)
          .load_with_lookahead(object, lookahead)
      end
    end

    # Defines a field with a conditional resolver depending on a feature flag.
    sig do
      params(
        # Name of the field
        name: T.any(String, Symbol),

        # GraphQL return type
        type: T.untyped,

        # Fallback method to call when the flag is disabled
        original_method: T.proc.params(args: T.untyped).returns(T.untyped),

        # Whether the field is nullable
        null: T::Boolean,

        # Field options such as description, method name override, etc.
        options: T::Hash[Symbol, T.untyped],

        # Optional block for defining arguments, etc.
        block: T.nilable(T.proc.void)
      ).void
    end
    def flagged_association_field(
      name,
      type:,
      original_method:,
      null: true,
      **options,
      &block
    )
      # Define a field using the same extras mechanism to inject lookahead.
      field name, type, null: null, **options.merge(extras: [ :lookahead ]) do
        instance_eval(&block) if block
      end

      # Define a conditional resolver depending on the StupidFlags feature toggle.
      define_method(name) do |lookahead:, **args|
        if StupidFlags.enabled?(:association_loader)
          context.dataloader
            .with(Loaders::AssociationDataloaderWithLookahead, name)
            .load_with_lookahead(object, lookahead)
        else
          # Fall back to the explicitly passed method if the flag is off.
          instance_exec(**args, &original_method)
        end
      end
    end

    # Adds a Relay-style connection field for a given association with optional scoping logic.
    sig do
      params(
        # The name of the association (e.g., :comments)
        name: T.any(String, Symbol),

        # The GraphQL type of the items in the connection (e.g., Types::CommentType)
        type: T.untyped,

        # Whether the connection itself can be null
        null: T::Boolean,

        # Optional max number of records to return
        max_page_size: T.nilable(Integer),

        # Optional lambda that applies a scope to the underlying ActiveRecord relation
        scoped: T.nilable(
          T.proc.params(
            relation: ActiveRecord::Relation,
            args: T.untyped,
            context: T.untyped
          ).returns(ActiveRecord::Relation)
        ),

        # Additional field options
        options: T::Hash[Symbol, T.untyped],

        # Optional block to customize the field (e.g., to define arguments)
        block: T.nilable(T.proc.void)
      ).void
    end
    def association_connection(name, type:, null: false, max_page_size: nil, scoped: nil, **options, &block)
      connection_class = GraphQL::Pagination::ActiveRecordRelationConnection

      # Define a Relay-style connection field (e.g., `comments_connection`)
      field "#{name}_connection", type.connection_type, null: null, **options do
        instance_eval(&block) if block
      end

      # Define a resolver for the connection field that supports optional scoping and pagination.
      define_method("#{name}_connection") do |**args|
        # Fetch the base ActiveRecord relation from the object.
        relation = object.public_send(name)

        # Apply additional scoping if a scoped proc was provided.
        relation = scoped.call(relation, args, context) if scoped

        # Wrap the relation in a GraphQL connection class and apply pagination.
        connection.max_page_size = max_page_size if max_page_size
        connection
      end
    end
  end
end
