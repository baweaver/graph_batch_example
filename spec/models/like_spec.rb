require 'rails_helper'

RSpec.describe Like, type: :model do
  describe 'associations' do
    it { should belong_to(:comment) }
    it { should belong_to(:user) }
  end

  describe 'factory' do
    it 'is valid with valid attributes' do
      comment = FactoryBot.create(:comment)
      user = FactoryBot.create(:user)
      expect(FactoryBot.build(:like, comment: comment, user: user)).to be_valid
    end

    it 'can create a like for a comment and user' do
      comment = FactoryBot.create(:comment)
      user = FactoryBot.create(:user)
      like = FactoryBot.create(:like, comment: comment, user: user)
      expect(like.comment).to eq(comment)
      expect(like.user).to eq(user)
    end
  end
end
