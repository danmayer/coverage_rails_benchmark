Coverband.configure do |config|
  config.root              = Dir.pwd
  config.collector         = 'coverage' if ENV['COVERBAND_COVERAGE']

  if defined? Redis
    config.redis           = Redis.new()
  end
  # don't want to use redis, store to file system ;)
  # config.coverage_file           = './tmp/coverband_coverage.json'

  # DEPRECATED now will use redis or file store
  # config.coverage_baseline = Coverband.parse_baseline

  config.root_paths        = ['/app/'] # /app/ is needed for heroku deployments
  # regex paths can help if you are seeing files duplicated for each capistrano deployment release
  # config.root_paths       = ['/server/apps/my_app/releases/\d+/']
  config.ignore            = ['vendor','lib/scrazy_i18n_patch_thats_hit_all_the_time.rb']
  # Since rails and other frameworks lazy load code. I have found it is bad to allow
  # initial requests to record with coverband. This ignores first 15 requests
  # NOTE: If you are using a threaded webserver (example: Puma) this will ignore requests for each thread
  config.startup_delay     = Rails.env.production? ? 0 : 0

  # This is used slightly differently by different Collectors
  # for the coverage implementation this is how often to process and upload the coverage data
  # for the coverage if you want to have the data uploaded on only 1 percent of your requests you will get a slow
  # and steady constant update of lines used in production
  #
  # for tracepoint this is how often to COLLECT and upload the data
  coverage_percent         = ENV['COVERAGE_PERCENT'] ? ENV['COVERAGE_PERCENT'].to_f : 100.0
  config.percentage        = Rails.env.production? ? coverage_percent : 100.0
  config.logger            = Rails.logger

  # config options false, true, or 'debug'. Always use false in production
  # true and debug can give helpful and interesting code usage information
  # they both increase the performance overhead of the gem a little.
  # they can also help with initially debugging the installation.
  # config.verbose           = true
end

###
# The below code will capture all the remaining coverage from the threads and report it before exit
# If puma is told to exit by signal or cntrl-c this ensures we capture remaining coverage
###
require 'puma/server'
module Puma
  class ThreadPool
    def shutdown(timeout=-1)
      puts "*"*90
      puts "override shutdown"
      threads = @mutex.synchronize do
        @shutdown = true
        @not_empty.broadcast
        @not_full.broadcast

        @auto_trim.stop if @auto_trim
        @reaper.stop if @reaper
        # dup workers so that we join them all safely
        @workers.dup
      end

      threads.each do |t|
        if t[:coverband_instance]
          t[:coverband_instance].start
          t[:coverband_instance].report_coverage
        end
      end

      if timeout == -1
        # Wait for threads to finish without force shutdown.
        threads.each(&:join)
      else
        # Wait for threads to finish after n attempts (+timeout+).
        # If threads are still running, it will forcefully kill them.
        timeout.times do
          threads.delete_if do |t|
            t.join 1
          end

          if threads.empty?
            break
          else
            sleep 1
          end
        end

        threads.each do |t|
          t.raise ForceShutdown
        end

        threads.each do |t|
          t.join SHUTDOWN_GRACE_TIME
        end
      end

      @spawned = 0
      @workers = []
    end
  end
end

###
# below is called on the lead process
# IE thread.current gets one that isn't running any of the workers
###
# require 'puma/single'
# module Puma
#   class Single < Runner
#      def stop_blocked
#        log "=== sending final coverage ==="
#        byebug
#        Thread.list
#        Coverband::Collectors::Base.instance.start
#        Coverband::Collectors::Base.instance.report_coverage
#        log "- Gracefully stopping, waiting for requests to finish"
#        @control.stop(true) if @control
#        @server.stop(true)
#      end
#   end
# end

###
# below is called on the lead process
# IE thread.current gets one that isn't running any of the workers
###
# module Puma
#   class Launcher
#     def graceful_stop
#       byebug
#       log "=== sending final coverage ==="
#       Coverband::Collectors::Base.instance.start
#       Coverband::Collectors::Base.instance.report_coverage
#       @runner.stop_blocked
#       log "=== puma shutdown: #{Time.now} ==="
#       log "- Goodbye!"
#     end
#   end
# end
