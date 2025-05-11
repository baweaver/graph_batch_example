require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'associations' do
    it { should belong_to(:post) }
    it { should belong_to(:author) }
    it { should have_many(:likes) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      post = FactoryBot.create(:post)
      author = FactoryBot.create(:author)
      expect(FactoryBot.build(:comment, post: post, author: author)).to be_valid
    end

    it 'can create a comment with likes' do
      post = FactoryBot.create(:post)
      author = FactoryBot.create(:author)
      comment = FactoryBot.create(:comment, post: post, author: author)
      like = FactoryBot.create(:like, comment: comment)
      expect(comment.likes).to include(like)
    end

    it 'can create a comment with a polymorphic author' do
      post = FactoryBot.create(:post)
      author = FactoryBot.create(:author)
      comment = FactoryBot.create(:comment, post: post, author: author)
      expect(comment.author).to eq(author)
    end
  end
end
