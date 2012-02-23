class User
  include DataMapper::Resource

  property :id, Serial
  property :login, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :forks

  def stale?
    time_now = DateTime.now
    cache_expires_at = self.updated_at + 1

    if time_now >= cache_expires_at
      return true
    else
      return false
    end
  end

  def refresh
    delete_cache
    create_cache
  end

  def delete_cache
    forks.destroy
  end

  def self.forks login
    user = User.first :login => login
    if user
      user.refresh if user.stale?
    else
      user = User.create :login => login
      user.create_cache
    end
    user.forks.collect {|f| { :owner => f.owner, :name => f.name } }
  end

  def create_cache
    repos = []
    page = 1
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{login}/repos?page=#{page}&per_page=100")
      page += 1
    end until a.empty?

    return repos if repos.empty?

    EventMachine.run do
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
        EventMachine.stop
      end
    end
  end
end
