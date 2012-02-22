class Fork
  include DataMapper::Resource

  property :id, Serial
  property :owner, String
  property :name, String
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :user
end
