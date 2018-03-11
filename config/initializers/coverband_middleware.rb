if ENV['COVERBAND']
  require 'coverband'
  Coverband.configure
end

module Coverband
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      Coverband::Collectors::Base.instance.configure_sampling
      Coverband::Collectors::Base.instance.record_coverage
      @app.call(env)
    ensure
      if ENV['IGNORED_COVERAGE']
        Coverband::Collectors::Base.instance.send(:unset_tracer)
      else
        Coverband::Collectors::Base.instance.report_coverage
      end
    end

  end
end
