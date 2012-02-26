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
      EventMachine.run do
        req = Repository::get_contributions(params[:owner], params[:repo], params[:user])
        req.callback do |contributions|
          response = {:count => contributions}
          EventMachine.stop
        end
        req.errback do |message|
          response = {:error => message}
          EventMachine.stop
        end
      end
      response.to_json
    end

    get '/contributions/:user' do
      response = []
      EventMachine.run do
        req = User.forks(params[:user])
        req.callback do |forks|
          EventMachine.stop if forks.empty?
          remain = 0
          forks.each do |branch|
            Repository::get_contributions(branch[:owner], branch[:name], params[:user]).callback do |contribution|
              response << branch unless contribution.zero?
              remain += 1
              EventMachine.stop if remain == forks.length
            end
          end
        end
        req.errback do |message|
          response = {:error => message}
          EventMachine.stop
        end
      end
      response.to_json
    end
  end
end
