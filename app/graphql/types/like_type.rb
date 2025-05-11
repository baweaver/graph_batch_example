module Types
  class LikeType < Types::BaseObject
    field :id, ID, null: false

    flagged_association_field :user,
      type: Types::UserType,
      null: true,
      original_method: -> { object.user }
  end
end
