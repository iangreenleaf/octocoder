class User
  include Cacheable
  include DataMapper::Resource
  include EventMachine::Deferrable
  extend EventMachine::Deferrable

  property :id, Serial
  property :login, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :forks

  def delete_cache
    forks.destroy
  end

  def self.forks login
    user = self.prime :login => login
    user.callback do |user|
      succeed user.forks.collect {|f| { :owner => f.owner, :name => f.name } }
    end
    self
  end

  def create_cache
    repos = []
    page = 1
    per_page = 100
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{login}/repos?page=#{page}&per_page=#{per_page}")
      page += 1
    end until a.length < per_page

    return succeed self if repos.empty?

    http = EventMachine::MultiRequest.new
    repos.each_with_index do |current,i|
      if current["fork"]
        http.add i, EventMachine::HttpRequest.new(
          "https://api.github.com/repos/#{current["owner"]["login"]}/#{current["name"]}"
        ).get
      end
    end
    http.callback do
      self.forks = http.responses[:callback].collect do |n,resp|
        source = JSON.parse( resp.response )["source"]
        Fork.new :owner => source["owner"]["login"], :name => source["name"]
      end
      save!
      succeed self
    end
  end
end
