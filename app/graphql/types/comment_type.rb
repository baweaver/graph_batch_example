module Types
  class CommentType < Types::BaseObject
    field :id, ID, null: false
    field :body, String, null: true

    association_field :post, type: Types::PostType, null: true
    association_field :likes, type: [ Types::LikeType ], null: true
    association_field :author, type: Types::UserType, null: true
  end
end
