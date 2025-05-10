class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :author, polymorphic: true
  has_many :likes
end
