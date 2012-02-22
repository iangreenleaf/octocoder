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
          http = EventMachine::HttpRequest.new(
            "https://api.github.com/repos/#{current["owner"]["login"]}/#{current["name"]}"
          ).get
          http.callback do
            remain -= 1
            source = JSON.parse( http.response )["source"]
            forks << { :owner => source["owner"]["login"], :name => source["name"] }
            EventMachine.stop if remain <= 0
          end
        end
      end
    end
    forks
  end
end
