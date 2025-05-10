10.times do
  author = Author.create!(name: Faker::Name.name)
  profile = Profile.create!(bio: Faker::Quote.matz, author: author)
  post = Post.create!(title: Faker::Book.title)

  5.times do
    comment = Comment.create!(body: Faker::Lorem.sentence, post: post, author: author)
    3.times do
      user = User.create!(name: Faker::Name.name)
      Like.create!(comment: comment, user: user)
    end
  end

  3.times do
    Tag.create!(name: Faker::Lorem.word, post: post)
  end
end
