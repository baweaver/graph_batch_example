FactoryBot.define do
  factory :profile do
    bio { Faker::Quote.famous_last_words }
    association :author
  end
end
