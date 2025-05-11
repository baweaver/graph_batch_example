module Loaders
  class ScopedConnectionLoader < GraphQL::Dataloader::Source
    extend T::Sig

    sig do
      params(
        association_name: T.any(String, Symbol),
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
        parents: T::Array[ActiveRecord::Base]
      ).returns(T::Array[GraphQL::Pagination::Connections::BaseConnection])
    end
    def fetch(parents)
      parents.map do |parent|
        association = parent.association(@association_name)
        base = T.let(association.scope, ActiveRecord::Relation)
        scoped = @scope_proc.call(base, nil, nil)
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
