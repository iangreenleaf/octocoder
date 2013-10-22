require File.dirname(__FILE__) + '/cacheable'
class User

  include Cacheable
  include ApiResource
  include DataMapper::Resource

  property :id, Serial
  property :login, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :forks

  def delete_cache
    forks.destroy!
  end

  def self.forks login
    user = self.prime :login => login
    user.forks.collect {|f| f.attributes }
  end

  def create_cache
    repos = []
    page = 1
    per_page = 100
    begin
      repos += (a = JSON.parse api_request("https://api.github.com/users/#{login}/repos?page=#{page}&per_page=#{per_page}").run.body)
      page += 1
    rescue => e
      raise e.message.to_s
    end until a.length < per_page

    return self if repos.empty?

    hydra = Typhoeus::Hydra.hydra
    repos.each do |current|
      if current["fork"]
        req = api_request "https://api.github.com/repos/#{current["owner"]["login"]}/#{current["name"]}"
        req.on_complete do |response|
          source = JSON.parse( response.body )["source"]
          attrs = source.reject do |k,v|
            Fork.properties[k].nil?
          end
          self.forks << Fork.new(attrs)
        end
        hydra.queue req
      end
    end
    hydra.run
    save!
    touch
  end
end
