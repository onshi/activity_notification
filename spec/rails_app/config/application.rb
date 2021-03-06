require File.expand_path('../boot', __FILE__)

# Load mongoid configuration if necessary:
if ENV['AN_ORM'] == 'mongoid'
  require 'mongoid'
  require 'rails'
  unless Rails.env.test?
    Mongoid.load!(File.expand_path("config/mongoid.yml"), :development)
  end
# Load dynamoid configuration if necessary:
elsif ENV['AN_ORM'] == 'dynamoid'
  require 'dynamoid'
  require 'rails'
  require File.expand_path('../dynamoid', __FILE__)
end

# Pick the frameworks you want:
if ENV['AN_ORM'] == 'mongoid' && ENV['AN_TEST_DB'] == 'mongodb'
  require "mongoid/railtie"
else
  require "active_record/railtie"
end
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require 'action_cable/engine' if Rails::VERSION::MAJOR >= 5

Bundler.require(*Rails.groups)
require "activity_notification"

module Dummy
  class Application < Rails::Application
    # Do not swallow errors in after_commit/after_rollback callbacks.
    if Rails::VERSION::MAJOR == 4 && Rails::VERSION::MINOR >= 2 && ENV['AN_TEST_DB'] != 'mongodb'
      config.active_record.raise_in_transactional_callbacks = true
    end
    if Rails::VERSION::MAJOR >= 5 && Rails::VERSION::MINOR >= 2 && ENV['AN_TEST_DB'] != 'mongodb'
      config.active_record.sqlite3.represent_boolean_as_integer = true
    end

    # Configure CORS for API mode
    if defined?(Rack::Cors)
      config.middleware.insert_before 0, Rack::Cors do
        allow do
          origins '*'
          resource '*',
            headers: :any,
            expose: ['access-token', 'client', 'uid'],
            methods: [:get, :post, :put, :delete]
        end
      end
    end
  end
end

puts "ActivityNotification test parameters: AN_ORM=#{ENV['AN_ORM'] || 'active_record(default)'} AN_TEST_DB=#{ENV['AN_TEST_DB'] || 'sqlite(default)'}"
