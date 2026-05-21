class User < ActiveRecord::Base
  has_many :posts, dependent: :destroy
  validates :email, presence: true, uniqueness: true
end
