module Types
  class CommentType < Types::BaseObject
    field :id, ID, null: false
    field :body, String, null: true
    field :spam, Boolean, null: true

    flagged_association_field :post,
      type: Types::PostType,
      null: true,
      original_method: -> { object.post }

    flagged_association_field :likes,
      type: [ Types::LikeType ],
      null: true,
      original_method: -> { object.likes }

    flagged_association_field :author,
      type: Types::UserType,
      null: true,
      original_method: -> { object.author }
  end
end
