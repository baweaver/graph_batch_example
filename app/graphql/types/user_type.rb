module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true

    field :profile, Types::ProfileType, null: false
    def profile
      object.profile
    end
  end
end
