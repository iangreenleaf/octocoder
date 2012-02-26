ENV["RACK_ENV"] ||= "development"

require 'bundler'
Bundler.setup

Bundler.require(:default, ENV["RACK_ENV"].to_sym)

Dir["./lib/**/*.rb"].each { |f| require f }

DataMapper::Logger.new($stdout, :debug) if ENV["RACK_ENV"] == "development"
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite3://my.db')
DataMapper.auto_upgrade!

