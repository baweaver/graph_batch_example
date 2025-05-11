module Types
  class AuthorType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true

    flagged_association_field :profile,
      type: Types::ProfileType,
      null: true,
      original_method: -> { object.profile }
  end
end
