require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require_relative '../app/middleware/coverage_wrapper'
require 'coverage'

module Blog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    if ENV['COVERBAND']
      # Coverband use Middleware
      require 'coverband'
      require 'redis'
      config.middleware.use Coverband::Middleware
    else
      # similar to coverband but using coverage opposed to tracepoint
      config.middleware.use CoverageWrapper
    end

    config.before_eager_load do |app|
      Coverage.start if ENV['COVERAGE_RESUME'] || ENV['COVERAGE_PAUSE'] || ENV['COVERAGE'] || ENV['COVERAGE_STOPPED'] || ENV['COVERBAND_COVERAGE']
    end

    config.after_initialize do |app|
      if ENV['COVERAGE_RESUME'] || ENV['COVERAGE_PAUSE'] || ENV['COVERAGE']
        Coverage.pause
      end
      if ENV['COVERAGE_STOPPED']
        Coverage.result
      end
    end

  end
end
