class User
  def self.forks username
    repos = []
    page = 1
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{username}/repos?page=#{page}&per_page=100")
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
        forks = http.responses[:callback].collect do |n,resp|
          source = JSON.parse( resp.response )["source"]
          { :owner => source["owner"]["login"], :name => source["name"] }
        end
        EventMachine.stop
        return forks
      end
    end
  end
end
