class User
  def self.forks username
    repos = []
    page = 1
    begin
      repos += (a = JSON.parse RestClient.get "https://api.github.com/users/#{username}/repos?page=#{page}&per_page=100")
      page += 1
    end until a.empty?

    repos.inject([]) do |forks,current|
      if current["fork"]
        repo = JSON.parse RestClient.get "https://api.github.com/repos/#{current["owner"]["login"]}/#{current["name"]}"
        source = repo["source"]
        forks << { :owner => source["owner"]["login"], :name => source["name"] }
      end
      forks
    end
  end
end
