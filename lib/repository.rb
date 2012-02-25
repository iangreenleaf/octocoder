class Repository  
  include Cacheable
  include DataMapper::Resource
  include EventMachine::Deferrable
  extend EventMachine::Deferrable
  
  property :id, Serial
  property :owner, String
  property :name, String
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :contributions

  def delete_cache
    contributions.destroy
  end

  def create_cache
    cache_contributors_from_github(self.id)
  end
  
  def cache_contributors_from_github(repository_id)
    contributors_http = EventMachine::HttpRequest.new("https://api.github.com/repos/#{self.owner}/#{self.name}/contributors").get
    contributors_http.callback do
      contributors_json = JSON.parse(contributors_http.response)
      contributors_json.each do |contributor|
        contribution = Contribution.create(:repository => Repository.get(repository_id), :user => contributor['login'], :count => contributor['contributions'])
      end
      self.succeed self
    end
  end
  
  def self.get_contributions(owner, repo, user)
    d = Dummy.new
    repository = prime :owner => owner, :name => repo
    repository.callback do |repository|
      contribution = Contribution.first(:user => user, :repository => repository)
      if contribution
        contributions = contribution['count']
      else
        contributions = 0
      end
      d.succeed contributions
    end
    d
  end
end

# I can only assume my use of this class indicates serious structural problems
class Dummy
  include EventMachine::Deferrable
end
