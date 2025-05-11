FactoryBot.define do
  factory :post do
    title { Faker::Book.title }
  end
end
