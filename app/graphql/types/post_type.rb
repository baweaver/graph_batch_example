module Types
  class PostType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: true

    association_field :tags, type: [ Types::TagType ], null: true
    association_field :profile, type: Types::ProfileType, null: true
    association_field :comments, type: [ Types::CommentType ], null: true

    association_connection :comments,
      type: Types::CommentType,
      null: false,
      max_page_size: 25,
      scoped: ->(scope, args, ctx) {
        scope.where(spam: false).order(created_at: :desc)
      } do
        argument :not_spam, Boolean, required: false
      end
  end
end
