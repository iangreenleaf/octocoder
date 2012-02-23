class Repository  
  include Cacheable
  include DataMapper::Resource
  
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
    contributors_text = RestClient.get "https://api.github.com/repos/#{self.owner}/#{self.name}/contributors"
    contributors_json = JSON.parse(contributors_text)
    
    contributors_json.each do |contributor|
      contribution = Contribution.create(:repository => Repository.get(repository_id), :user => contributor['login'], :count => contributor['contributions'])
    end
  end
  
  def self.get_contributions(owner, repo, user)
    contributions = 0
    repository = prime :owner => owner, :name => repo
    contribution = Contribution.first(:user => user, :repository => repository)
    if contribution
      contributions = contribution['count']
    end
    return contributions
  end
end
