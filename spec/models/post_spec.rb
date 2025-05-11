require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'associations' do
    it { should have_many(:comments) }
    it { should have_many(:tags) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      expect(FactoryBot.build(:post)).to be_valid
    end

    it 'can create a post with comments and tags' do
      post = FactoryBot.create(:post)
      comment = FactoryBot.create(:comment, post: post)
      tag = FactoryBot.create(:tag, post: post)
      expect(post.comments).to include(comment)
      expect(post.tags).to include(tag)
    end
  end
end
