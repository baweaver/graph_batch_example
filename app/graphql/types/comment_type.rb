module Types
  class CommentType < Types::BaseObject
    field :id, ID, null: false
    field :body, String, null: true
    field :post, Types::PostType, null: true
    field :author, Types::UserType, null: false
    field :likes, [ Types::LikeType ], null: false

    def likes
      object.likes
    end

    def author
      object.author
    end
  end
end
