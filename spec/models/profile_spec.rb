require 'rails_helper'

RSpec.describe Profile, type: :model do
  describe 'associations' do
    it { should belong_to(:author) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      expect(FactoryBot.build(:profile)).to be_valid
    end

    it 'can create a profile with an author' do
      author = FactoryBot.create(:author)
      profile = FactoryBot.create(:profile, author: author)
      expect(profile.author).to eq(author)
    end
  end
end
