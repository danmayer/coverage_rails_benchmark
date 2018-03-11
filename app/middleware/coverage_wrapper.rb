class CoverageWrapper

    def initialize(app)
      @app = app
    end

    def call(env)
      # TODO this doesn't work with threads
      sample = ENV['COVERAGE_SAMPLE'].to_i
      take_sample = true
      take_sample = (Time.now.to_i%2 > 0) if sample == 50
      if ENV['COVERAGE_RESUME'] && take_sample
        Coverage.resume
      end
      @app.call(env)
    ensure
      if ENV['COVERAGE_RESUME'] && take_sample
        Coverage.pause
      end
      unless ENV['IGNORED_COVERAGE']
        coverage_data = Coverage.peek_result
        Rails.logger.info coverage_data.inspect if ENV['COVERAGE_LOG']
      end
    end

end
