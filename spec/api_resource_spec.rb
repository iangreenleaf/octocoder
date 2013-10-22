require 'spec_helper'

describe "api resources" do
  let(:resource) { double("resource") }

  before(:each) do
    @credentials = {:client_id => "1234", :client_secret => "abcd"}
    resource.extend ApiResource
    resource.stub(:secret).and_return(@credentials)
  end

  describe "app credentials" do
    it "are sent with api requests" do
      stub = stub_request(
        :get,
        "https://api.github.com/foo"
      ).with(
        :query => @credentials
      )
      resource.api_request("https://api.github.com/foo").run
      stub.should have_been_requested
    end

    it "are merged with params in URL" do
      stub = stub_request(
        :get,
        "https://api.github.com/foo"
      ).with(
        :query => @credentials.merge(:foo => "bar")
      )
      resource.api_request("https://api.github.com/foo?foo=bar").run
      stub.should have_been_requested
    end

    it "are merged with params in arguments" do
      stub = stub_request(
        :get,
        "https://api.github.com/foo"
      ).with(
        :query => @credentials.merge(:foo => "bar")
      )
      resource.api_request("https://api.github.com/foo", :params => {:foo => "bar"}).run
      stub.should have_been_requested
    end
  end
end
