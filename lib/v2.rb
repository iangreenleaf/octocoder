require 'uri'
require 'net/http'
require 'net/https'

module CCS
  class V2< Sinatra::Base
    
    def self.new(*)
      super
    end
    
    get '/' do
      content_type :json
      message = Hash.new
      message[:message] = 'alive'
      message.to_json
    end
    
    get '/:owner/:repo/:user/?' do
      content_type :json

      response = nil
      begin
        contributions = Repository::get_contributions(params[:owner], params[:repo], params[:user])
        response = {:count => contributions}
      rescue => e
        response = {:error => e.message}
      end
      response.to_json
    end

    get '/contributions/:user' do
      response = []
      begin
        forks = User.forks(params[:user])
        unless forks.empty?
          forks.each do |branch|
            contributions = Repository::get_contributions(branch[:owner], branch[:name], params[:user])
            response << branch unless contributions.zero?
          end
        end
      rescue => e
        response = {:error => e.message}
      end
      response.to_json
    end
  end
end
