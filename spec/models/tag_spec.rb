require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'associations' do
    it { should belong_to(:post) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      post = FactoryBot.create(:post)
      expect(FactoryBot.build(:tag, post: post)).to be_valid
    end

    it 'can create a tag with a post' do
      post = FactoryBot.create(:post)
      tag = FactoryBot.create(:tag, post: post)
      expect(tag.post).to eq(post)
    end
  end
end
