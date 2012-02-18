class User
  def self.forks username
    repos = []
    page = 1
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{username}/repos?page=#{page}&per_page=100")
      page += 1
    end until a.empty?

    remain = 0
    forks = []
    EventMachine.run do
    repos.each do |current|
      if current["fork"]
        remain += 1
        http = EventMachine::Protocols::HttpClient2.connect(
          :host => "api.github.com",
          :port => 443,
          :ssl => true
        )
        req = http.get "/repos/#{current["owner"]["login"]}/#{current["name"]}"
        req.callback do |response|
          remain -= 1
          source = JSON.parse( response.content )["source"]
          forks << { :owner => source["owner"]["login"], :name => source["name"] }
          return forks if remain <= 0
        end
      end
      end
    end
  end
end
