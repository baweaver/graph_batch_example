module Types
  class LikeType < Types::BaseObject
    field :id, ID, null: false

    association_field :user, type: Types::UserType, null: true
  end
end
