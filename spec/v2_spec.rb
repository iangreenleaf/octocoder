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

    it "cache miss once enough time elapses" do
      get '/sinatra/sinatra/leereilly/'
      Timecop.travel DateTime.now + 0.6
      get '/sinatra/sinatra/leereilly/'
      WebMock.should have_requested(:any, /.*/).once
      Timecop.travel DateTime.now + 0.6
      get '/sinatra/sinatra/leereilly/'
      WebMock.should have_requested(:any, /.*/).twice
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
      last_response.body.should == '{"error":"Not Found"}'
    end
  end

  describe "GET '/contributions/foobar'" do
    before do
      stub_request(
        :get,
        %r|https://api\.github\.com/users/foobar/repos\?.*|
      ).to_return(
        :body => '[{"name":"linux","fork":true,"owner":{"login":"foobar"}},
        {"name":"my_thing","fork":false,"owner":{"login":"foobar"}},
        {"name":"didnt_contrib","fork":true,"owner":{"login":"foobar"}},
        {"name":"git","fork":true,"owner":{"login":"foobar"}}]'
      )
      %w[linux git didnt_contrib].each do |r|
        stub_request(
          :get,
          "https://api.github.com/repos/foobar/#{r}"
      ).to_return(
          :body => '{"source":{"name":"'+r+'","html_url":"https://github.com/linus/'+r+'","owner":{"login":"linus"},"created_at":"2001-01-01T04:26:53Z","id": 12345}}'
        )
      end
      stub_request(
        :get,
        %r~https://api.github.com/repos/linus/(linux|git)/contributors~
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
      response = JSON.parse last_response.body
      response.length.should == 2
      response.first["name"].should == "linux"
      response.first["owner"].should == "linus"
      response.first["html_url"].should == "https://github.com/linus/linux"
      response.last["name"].should == "git"
      response.last["owner"].should == "linus"
      response.last["html_url"].should == "https://github.com/linus/git"
    end

    it "should not get confused by special properties" do
      get '/contributions/foobar'
      response = JSON.parse last_response.body
      response.first["fork_created_at"].should == "2001-01-01T04:26:53Z"
      response.first["created_at"].should_not == "2001-01-01T04:26:53Z"
      response.first["id"].should be_nil
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
      JSON.parse(last_response.body).length.should == 2
      WebMock.should have_requested(:any, %r|/users/foobar/repos|).once
      WebMock.should have_requested(:any, %r|/repos/linus/linux/contributors|).once
    end

    it "cache miss once enough time elapses" do
      get '/contributions/foobar'
      Timecop.travel DateTime.now + 0.6
      get '/contributions/foobar'
      WebMock.should have_requested(:any, %r|/users/foobar/repos|).once
      Timecop.travel DateTime.now + 0.6
      get '/contributions/foobar'
      WebMock.should have_requested(:any, %r|/users/foobar/repos|).twice
    end

    it "is cached again later" do
      get '/contributions/foobar'
      Timecop.travel DateTime.now + 1.1
      get '/contributions/foobar'
      get '/contributions/foobar'
      WebMock.should have_requested(:any, %r|/users/foobar/repos|).twice
    end

    it "reuses contributions cache" do
      get '/linus/linux/foobar'
      get '/contributions/foobar'
      JSON.parse(last_response.body).length.should == 2
      WebMock.should have_requested(:any, %r|/repos/linus/linux/contributors|).once
    end

    it "should return an error if the repo doesn't exist" do
      stub_request(
        :get,
        %r|https://api\.github\.com/users/barbaz/repos\?.*|
      ).to_return(
        :body => '{"message":"Not Found"}',
        :status => ["404", "Not Found"]
      )
      get '/contributions/barbaz'
      last_response.body.should == '{"error":"404 Resource Not Found"}'
    end
  end

  describe "GET '/contributions/foobar' with large response" do
    it "sends multiple requests for repos if necessary" do
      big_payload = (1..100).collect do |n|
        { :name => "abc#{n}", :fork => false, :owner => { :login => "prolific" } }
      end
      stub_request(
        :get,
        %r|https://api\.github\.com/users/prolific/repos\?.*|
      ).to_return(
        { :body => big_payload.to_json },
        { :body => '[{"name":"second_batch","fork":true,"owner":{"login":"prolific"}}]' }
      )
      stub_request(
        :get,
        "https://api.github.com/repos/prolific/second_batch"
      ).to_return(
        :body => '{"source":{"name":"second_batch","owner":{"login":"linus"}}}'
      )
      stub_request(
        :get,
        "https://api.github.com/repos/linus/second_batch/contributors"
      ).to_return(
        :body => '[{"login":"prolific","contributions":3}]'
      )
      get '/contributions/prolific'
      response = JSON.parse last_response.body
      response.length.should == 1
      response.first["name"].should == "second_batch"
      response.first["owner"].should == "linus"
    end
  end
end
