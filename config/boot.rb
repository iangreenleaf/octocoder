ENV["RACK_ENV"] ||= "development"

require 'bundler'
Bundler.setup

Bundler.require(:default, ENV["RACK_ENV"].to_sym)

DataMapper::Logger.new($stdout, :debug) if ENV["RACK_ENV"] == "development"
DataMapper::Property::String.length(255)
DataMapper::Model.raise_on_save_failure = false

Dir["./lib/**/*.rb"].each { |f| require f }

$logger = Logger.new($stdout, :debug) if ENV["RACK_ENV"] == "development"

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite3://my.db')
DataMapper.auto_upgrade!

