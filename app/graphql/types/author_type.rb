module Types
  class AuthorType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :profile, Types::ProfileType, null: true
  end
end
