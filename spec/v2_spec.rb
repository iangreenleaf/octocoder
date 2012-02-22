require 'spec_helper'

describe CCS::V2 do
  before do
    Repository.all.destroy!
    Contribution.all.destroy!
    User.all.destroy!
    Fork.all.destroy!

    %w[sinatra/sinatra leereilly/leereilly.net].each do |r|
      stub_request(
        :get,
        "https://api.github.com/repos/#{r}/contributors"
      ).to_return(
        :body => '[{"login":"leereilly","contributions":3}]'
      )
    end
  end

  def app
    @app ||= CCS::V2
  end
  
  # Valid owner, valid repo, valid user
  describe "GET '/sinatra/sinatra/leereilly'" do  
    it "should be successful" do
      get '/sinatra/sinatra/leereilly/'
      last_response.should be_ok
    end
    
    it "should find the correct number of contributions" do
      get '/sinatra/sinatra/leereilly/'
      last_response.body.should == '{"count":3}'
    end
    
    it "caches the repo" do
      get '/sinatra/sinatra/leereilly/'
      get '/sinatra/sinatra/leereilly/'
      WebMock.should have_requested(:any, /.*/).once
    end
  end
  
  # Valid owner, valid repo, invalid user
  describe "GET '/sinatra/sinatra/admin'" do  
    it "should find the correct number of contributions for a cached repo" do
      get '/sinatra/sinatra/leereilly/'
      get '/sinatra/sinatra/admin/'
      last_response.body.should == '{"count":0}'
    end
    
    it "should find the correct number of contributions for an uncached repo" do
      get '/leereilly/leereilly.net/admin/'
      last_response.body.should == '{"count":0}'
    end
    
    it "should return an error if the repo doesn't exist" do
      stub_request(
        :get,
        "https://api.github.com/repos/admin/schmadmin/contributors"
      ).to_return(
        :body => '{"message":"Not Found"}',
        :status => ["404", "Not Found"]
      )
      get '/admin/schmadmin/schnarf-schnarf/'
      last_response.body.should == '{"error":"404 Resource Not Found"}'
    end
  end

  describe "GET '/contributions/foobar'" do
    before do
      stub_request(
        :get,
        %r|https://api\.github\.com/users/foobar/repos\?.*|
      ).to_return(
        {:body => '[{"name":"linux","fork":true,"owner":{"login":"foobar"}},
        {"name":"my_thing","fork":false,"owner":{"login":"foobar"}},
        {"name":"didnt_contrib","fork":true,"owner":{"login":"foobar"}}]'},
        {:body => '[]'}
      )
      %w[linux didnt_contrib].each do |r|
        stub_request(
          :get,
          "https://api.github.com/repos/foobar/#{r}"
      ).to_return(
          :body => '{"source":{"name":"'+r+'","owner":{"login":"linus"}}}'
        )
      end
      stub_request(
        :get,
        "https://api.github.com/repos/linus/linux/contributors"
      ).to_return(
        :body => '[{"login":"foobar","contributions":3}]'
      )
      stub_request(
        :get,
        "https://api.github.com/repos/linus/didnt_contrib/contributors"
      ).to_return(
        :body => '[{"login":"someone_else","contributions":3}]'
      )
    end

    it "should find projects contributed to" do
      get '/contributions/foobar'
      last_response.body.should == '[{"name":"linux","owner":"linus"}]'
    end

    it "works if no repos found" do
      stub_request(
        :get,
        %r|https://api\.github\.com/users/foobar/repos\?.*|
      ).to_return(
        :body => "[]"
      )
      get '/contributions/foobar'
      last_response.body.should == '[]'
    end

    it "caches the request" do
      get '/contributions/foobar'
      get '/contributions/foobar'
      last_response.body.should == '[{"name":"linux","owner":"linus"}]'
      WebMock.should have_requested(:any, %r|/users/foobar/repos|).twice
    end

    it "reuses contributions cache" do
      get '/linus/linux/foobar'
      get '/contributions/foobar'
      last_response.body.should == '[{"name":"linux","owner":"linus"}]'
      WebMock.should have_requested(:any, %r|/repos/linus/linux/contributors|).once
    end
  end
end
