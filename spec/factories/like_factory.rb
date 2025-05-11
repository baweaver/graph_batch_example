FactoryBot.define do
  factory :like do
    association :comment
    association :user
  end
end
