require File.dirname(__FILE__) + '/cacheable'
class Repository  
  include ApiResource
  include Cacheable
  include DataMapper::Resource
  
  property :id, Serial
  property :owner, String
  property :name, String
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :contributions

  def delete_cache
    contributions.destroy!
  end

  def create_cache
    cache_contributors_from_github(self.id)
  end
  
  def cache_contributors_from_github(repository_id)
    req = api_request("https://api.github.com/repos/#{self.owner}/#{self.name}/contributors").run
    if req.response_code == 200
      JSON.parse(req.response_body).each do |contributor|
        self.contributions.new(:user => contributor['login'], :count => contributor['contributions'])
      end
      self.save
      self.touch
    else
      raise JSON.parse(req.response_body)["message"]
    end
  end
  
  def self.get_contributions(owner, repo, user)
    repository = prime :owner => owner, :name => repo
    contrib = Contribution.first(:user => user, :repository => repository)
    (contrib ? contrib.count : 0)
  end
end
