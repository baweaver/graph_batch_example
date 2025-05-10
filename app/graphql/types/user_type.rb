module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true

    association_field :profile, type: Types::ProfileType, null: true
  end
end
