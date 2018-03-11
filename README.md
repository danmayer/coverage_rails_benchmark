# README

This is a project to benchmark the Ruby `Coverage` libraries performance impact.

It has a simple benchmark script that exercises the app in the Rails production environment, then a series of environment variables that can be used to control different mechanisms related to tracking runtime line usage.

The original goal was to show performance benefits to adding support in Ruby to pause and resume `Coverage`. The resulting data shows that it is far more time consuming to inspect and use the data to report coverage usage than it ever is to collect it via `Coverage` into Ruby's memory. Meaning one should not ever try to pause and resume coverage data collection, but instead, optimize around how often and when coverage is looked at.

# Default Runtime

This is a basic Rails 5.1 app, all tests are run in production mode: `RAILS_ENV=production bin/rails server`

The benchmark test is executed via: `ruby ./bin/benchmark.rb`, which makes 2000 requests with concurrency 5.

Originally, Forked from Ruby Trunk with Development of Ruby 2.6.0. To test the suggested Ruby patch, tests were done on this [Ruby fork](https://github.com/danmayer/ruby/).

* See the originally suggested (now retracted), [pause feature request see the diff](https://github.com/danmayer/ruby/compare/trunk...danmayer:feature/coverage_pause)

# Environment Controls

The app can be run in a number of modes.

* `No Coverage Support`: the `Coverage` library is required but `Coverage.start` and other methods are never called
* `Coverage Running`: on start `Coverage.start` is called early enough to load all `app/**` related files
* `Coverage Stopped`: on start `Coverage.start` is called early enough to load all `app/**` related files, but stopped before serving requests
* `Coverage Paused`: same as above, but uses new pause feature in patch vs stop
* `Coverage Resume`: same as above, but uses new pause and resume feature to toggle on and off `Coverage` during requests.
* `Coverband Coverage`: This doesn't call `Coverage` directly but uses the Coverband Gem in the new mode that runs `Coverage`. This is most similar to `Coverage Running1`, but supports many additional features. Both Coverband use cases are shown with 100% sample rate.
   * This project had me re-evaluate that I needed `Coverage.pause` to use `Coverage` with `Coverband`. The beta [Coverband Coverage branch](https://github.com/danmayer/coverband/compare/feature/via_coverage) was created to validate a workable model and to benchmark against `Tracepoint` 
* `Coverband Tracepoint`: The original method Coverband used to collect the line of code usage via Ruby's Tracepoint API. Both Coverband use cases are shown with 100% sample rate.

All the modes above support two modes:

* `Ignore Coverage`: never inspecting or attempting to access `Coverage` data.
* `Collect Coverage`: a mode where they attempt to collect and use Coverage data.
 
# Benchmark Results

The results below are listed in fastest to slowest, with some comments about impact changes throughout the performance progression.

__Tier 1__
Everything above the line has nearly identical performance across runs, showing no significant performance impacts or never using `Coverage` all the way through using `Coverage.start` directly or via the new `Coverband::Coverage`. In all these cases while Coverage data was collected, but never inspected or accessed in the app. This basically shows there is a very little impact of using Coverage.

__Tier 2__
This group is toggling coverage on and off using the pause feature or accessing coverage data via `Coverage.peek_results`. It is slower than `Tier 1` but still much faster than when trying to support full coverage reporting. This shows that by either accessing coverage data or trying to constantly pause and resume you are incurring extra overhead. Since my direct `Coverage` integration doesn't report anything it has a bit of an unfair advantage over `Coverband` with reporting here.

__Tier 3__
This group is WAY slower and shows two things:

* using the Tracepoint API to collect line usage data, even without accessing the data is MUCH slower than `Coverage`
* That processing data in any way other than just loading it into memory can have a huge cost. Logging the `Coverage.peek_results` data, for example, is much slower than even sending large amounts of filtered data to Redis (which is the primary reporting for Coverband). 

# Benchmark Conclusions

In the end, I don't think there is a reason to implement `Coverage.pause` and `Coverage.resume` as the performance savings of not listening to the `Coverage` events after the code is compiled to send them seems completely un-noticeable.

Moreover, this benchmarking made it clear to me that `Coverage` isn't only a viable option now with `Coverage.peek_results` that it is far superior to using the Ruby `Tracepoint` API for a line of code usage. Also, that the most costly thing is processing the `Coverage` data, not the collection of it. This is very different than the `Tracepoint` method which incurs a high cost both in the collection and in processing. 

While this will require a very different design in terms of how `Coverband` previously handled collection and sampling, It looks like the data from this benchmarking project should lead to the ability to collect and report production code usage data with orders of magnitude more performance than I have previously implemented. Namely, always collect and process outside of the request lifecycle totally moving away from a per request sampling originally used for the `Tracepoint` implementation.

## Tier 1

### No Coverage Support

```
IGNORED_COVERAGE=true RAILS_ENV=production bin/rails server

17.735 [ms] (mean)
  50%     17
  66%     19
  75%     21
  80%     23
  90%     27
  95%     31
  98%     37
  99%     41
 100%     92 (longest request)
```

### Coverage Running (Ignore Coverage)

```
IGNORED_COVERAGE=true COVERAGE=true RAILS_ENV=production bin/rails server

18.131 [ms] (mean)
  50%     17
  66%     20
  75%     21
  80%     23
  90%     26
  95%     29
  98%     35
  99%     40
 100%     94 (longest request)
```

### Coverage Stopped (Ignore Coverage)

```
IGNORED_COVERAGE=true COVERAGE_STOPPED=true RAILS_ENV=production bin/rails server

18.268 [ms] (mean) 
  50%     17
  66%     20
  75%     22
  80%     23
  90%     27
  95%     31
  98%     35
  99%     39
 100%     80 (longest request)
```

### Coverage Paused (Ignore Coverage)

```
IGNORED_COVERAGE=true COVERAGE_PAUSE=true RAILS_ENV=production bin/rails server

18.717 [ms] (mean)
  50%     17
  66%     20
  75%     22
  80%     24
  90%     28
  95%     33
  98%     40
  99%     46
 100%     76 (longest request)
```

### Coverband Coverage (Ignore Coverage)
```
IGNORED_COVERAGE=true COVERBAND_COVERAGE=true COVERBAND=true RAILS_ENV=production bin/rails server

18.759 [ms] (mean)
  50%     18
  66%     20
  75%     22
  80%     23
  90%     27
  95%     31
  98%     36
  99%     42
 100%     81 (longest request)
```

---
## Tier 2

### Coverage Running (Collect Coverage, but only into memory)
```
COVERAGE=true RAILS_ENV=production bin/rails server

21.141 [ms] (mean)
  50%     20
  66%     23
  75%     25
  80%     27
  90%     31
  95%     34
  98%     38
  99%     41
 100%    160 (longest request)
```

### Coverage Resume (Ignore Coverage)

This is sampling at 100%, which makes no sense for the pause and resume feature, which generally, would be used to sample a portion of requests. This does give a good idea of the cost of toggling it on and off though.

```
IGNORED_COVERAGE=true COVERAGE_RESUME=true RAILS_ENV=production bin/rails server

23.930 [ms] (mean)
  50%     22
  66%     26
  75%     29
  80%     30
  90%     36
  95%     41
  98%     49
  99%     54
 100%     96 (longest request)
```

### Coverage Resume (Collect Coverage, but only into memory)

This is sampling at 100%, which makes no sense for the pause and resume feature, which generally, would be used to sample a portion of requests. This does give a good idea of the cost of toggling it on and off though.

```
COVERAGE_RESUME=true RAILS_ENV=production bin/rails server

26.720 [ms] (mean)
  50%     25
  66%     29
  75%     32
  80%     33
  90%     40
  95%     45
  98%     54
  99%     60
 100%     76 (longest request)
```

## Tier 3	

### Coverband Coverage (Collect Coverage)

```
COVERBAND_COVERAGE=true COVERBAND=true RAILS_ENV=production bin/rails server

39.421 [ms] (mean)
  50%     29
  66%     41
  75%     51
  80%     58
  90%     81
  95%    102
  98%    131
  99%    146
 100%    246 (longest request)
```

### Coverband Tracepoint (Collect Coverage)

```
COVERBAND=true RAILS_ENV=production bin/rails server (100% sample)

46.979 [ms] (mean)
  50%     37
  66%     51
  75%     58
  80%     66
  90%     83
  95%    106
  98%    136
  99%    156
 100%    316 (longest request)
```

### Coverband Tracepoint (Ignore Coverage)

```
IGNORED_COVERAGE=true COVERBAND=true RAILS_ENV=production bin/rails server

47.500 [ms] (mean)
  50%     45
  66%     52
  75%     56
  80%     59
  90%     69
  95%     79
  98%     92
  99%    106
 100%    167 (longest request)
```

### Coverage (Collect Coverage, send to Rails.logger)

For this example, I logged `Coverage.peek_results` to Rails logger. This shows how large of a cost it can be to process the collected data and really shows some of the value to Coverbands additional features around processing. 

```
COVERAGE=true COVERAGE_LOG=true RAILS_ENV=production bin/rails server

85.069 [ms] (mean)
  50%     80
  66%     94
  75%    101
  80%    110
  90%    129
  95%    149
  98%    168
  99%    191
 100%    308 (longest request)
```