module Types
  class PostType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: true

    association_field :tags, type: [ Types::TagType ], null: true
    association_field :comments, type: [ Types::CommentType ], null: true
    association_field :profile, type: Types::ProfileType, null: true
  end
end
