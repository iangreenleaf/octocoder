class Repository  
  include Cacheable
  include DataMapper::Resource
  include EventMachine::Deferrable
  
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
    req = EventMachine::HttpRequest.new("https://api.github.com/repos/#{self.owner}/#{self.name}/contributors").get
    req.callback do
      if req.response_header.status == 200
        JSON.parse(req.response).each do |contributor|
          self.contributions.new(:user => contributor['login'], :count => contributor['contributions'])
        end
        self.save
        succeed self
      else
        fail JSON.parse(req.response)["message"]
      end
    end
  end
  
  def self.get_contributions(owner, repo, user)
    d = RepositoryDummy.new
    deferred = prime :owner => owner, :name => repo
    deferred.callback do |repository|
      contribution = Contribution.first(:user => user, :repository => repository)
      if contribution
        contributions = contribution['count']
      else
        contributions = 0
      end
      d.succeed contributions
    end
    deferred.errback {|e| d.fail e }
    d
  end
end

# I can only assume my use of this class indicates serious structural problems
class RepositoryDummy
  include EventMachine::Deferrable
end
