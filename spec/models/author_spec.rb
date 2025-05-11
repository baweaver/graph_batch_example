require 'rails_helper'

RSpec.describe Author, type: :model do
  describe 'associations' do
    it { should have_one(:profile) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      expect(FactoryBot.build(:author)).to be_valid
    end

    it 'can create an author with a profile' do
      author = FactoryBot.create(:author)
      profile = FactoryBot.create(:profile, author: author)
      expect(profile.author).to eq(author)
    end
  end
end
