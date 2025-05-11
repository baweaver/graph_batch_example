module Loaders
  # A custom GraphQL dataloader source for paginated associations
  # that supports applying additional scopes (e.g., filters, sorting, authorization)
  # via a passed-in Proc.
  class ScopedConnectionLoader < GraphQL::Dataloader::Source
    extend T::Sig

    sig do
      params(
        # The name of the ActiveRecord association to load from each parent record.
        # Can be passed as a symbol or string, e.g. :comments.
        association_name: T.any(String, Symbol),

        # A Proc that applies additional scoping logic to the base relation.
        #
        # It accepts:
        #   - base: The unscoped ActiveRecord relation returned by the association
        #   - args: The GraphQL field arguments (optional)
        #   - ctx: The GraphQL context object (optional)
        #
        # The proc must return an ActiveRecord::Relation suitable for connection pagination.
        scope_proc: T.proc.params(
          base: ActiveRecord::Relation,
          args: T.untyped,
          ctx: T.untyped
        ).returns(ActiveRecord::Relation)
      ).void
    end
    def initialize(association_name:, scope_proc:)
      @association_name = association_name.to_sym
      @scope_proc = scope_proc
    end

    sig do
      override.params(
        # An array of parent ActiveRecord models whose associations
        # will be lazily and independently loaded.
        parents: T::Array[ActiveRecord::Base]
      ).returns(
        # Each returned value is a paginated connection object that wraps
        # the scoped association for one of the parent models.
        T::Array[GraphQL::Pagination::Connections::BaseConnection]
      )
    end
    def fetch(parents)
      parents.map do |parent|
        # Retrieve the reflection for the association
        association = parent.association(@association_name)

        # Get the base relation of the association (unscope-aware)
        base = T.let(association.scope, ActiveRecord::Relation)

        # Apply additional filtering/scoping logic
        # Note: args and ctx are passed as nil here, but could be injected if needed
        scoped = @scope_proc.call(base, nil, nil)

        # Wrap the final scoped relation in a Relay-style connection object
        GraphQL::Pagination::Connections.connection_for_nodes(scoped)
      end
    end

    private

    sig { returns(Symbol) }
    attr_reader :association_name

    sig do
      returns(
        T.proc
          .params(base: ActiveRecord::Relation, args: T.untyped, ctx: T.untyped)
          .returns(ActiveRecord::Relation)
      )
    end
    attr_reader :scope_proc
  end
end
