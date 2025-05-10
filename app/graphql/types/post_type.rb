module Types
  class PostType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: true

    field :tags, [ Types::TagType ], null: false

    field :comments, [ Types::CommentType ], null: false
    def comments
      object.comments
    end

    field :profile, Types::ProfileType, null: false
    def profile
      object.profile
    end
  end
end
