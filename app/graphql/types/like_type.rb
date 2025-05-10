module Types
  class LikeType < Types::BaseObject
    field :id, ID, null: false
    field :user, Types::UserType, null: false

    def user
      object.user
    end
  end
end
