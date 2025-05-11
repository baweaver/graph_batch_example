FactoryBot.define do
  factory :comment do
    body { Faker::Lorem.sentence }
    spam { false }
    association :post
    association :author
  end
end
