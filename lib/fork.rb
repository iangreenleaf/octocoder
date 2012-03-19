class Fork
  include DataMapper::Resource

  property :id, Serial
  property :owner, String
  property :html_url, String
  property :url, String
  property :watchers, Integer
  property :forks, Integer
  property :pushed_at, DateTime
  property :fork_updated_at, DateTime
  property :fork_created_at, DateTime
  property :name, String
  property :description, String
  property :language, String
  property :name, String
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :user

  # Just filter the owner down to the login name
  def owner= data
    if data.kind_of? Hash
      data = data["login"]
    end
    self[:owner] = data
  end
end
