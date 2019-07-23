# typed: strong
class Booker < ApplicationRecord
  has_many :reservations
end
