# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    extend Helpers::AssociationLoader

    edge_type_class(Types::BaseEdge)
    connection_type_class(Types::BaseConnection)
    field_class Types::BaseField
  end
end
