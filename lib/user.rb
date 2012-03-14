require File.dirname(__FILE__) + '/cacheable'
class User
  include Cacheable
  include DataMapper::Resource
  include EventMachine::Deferrable

  property :id, Serial
  property :login, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :forks

  def delete_cache
    forks.destroy!
  end

  def self.forks login
    d = UserDummy.new
    user = self.prime :login => login
    user.callback do |user|
      d.succeed user.forks.collect {|f| { :owner => f.owner, :name => f.name } }
    end
    user.errback {|e| d.fail e }
    d
  end

  def create_cache
    repos = []
    page = 1
    per_page = 100
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{login}/repos?page=#{page}&per_page=#{per_page}")
      page += 1
    rescue => e
      return fail e.message.to_s
    end until a.length < per_page

    return succeed self if repos.empty?

    http = EventMachine::MultiRequest.new
    repos.each do |current|
      if current["fork"]
        http.add current, EventMachine::HttpRequest.new(
          "https://api.github.com/repos/#{current["owner"]["login"]}/#{current["name"]}"
        ).get
      end
    end
    http.callback do
      self.forks = http.responses[:callback].collect do |_,resp|
        source = JSON.parse( resp.response )["source"]
        Fork.new :owner => source["owner"]["login"], :name => source["name"]
      end
      save!
      succeed self
    end
  end
end

# I can only assume my use of this class indicates serious structural problems
class UserDummy
  include EventMachine::Deferrable
end
