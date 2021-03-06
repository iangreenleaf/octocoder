ENV['RACK_ENV'] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/boot")
require 'webmock/rspec'

Webrat.configure do |conf|
  conf.mode = :rack
end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.include Webrat::Methods
  conf.include Webrat::Matchers
  conf.before(:each) { WebMock.reset! }
  conf.after(:each) { Timecop.return }
end

WebMock.disable_net_connect!
