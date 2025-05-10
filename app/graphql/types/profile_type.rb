module Types
  class ProfileType < Types::BaseObject
    field :id, ID, null: false
    field :bio, String, null: true
  end
end
