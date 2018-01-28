# README

This is to help test coverband performance impact.

It will try to record the performance impact using AB of adding coverband. It will try to show perf wins from patching Ruby.

This is a basic Rails 5.1 app.

# Ruby 2.5.0

```
Server Software:
Server Hostname:        127.0.0.1
Server Port:            3000

Document Path:          /posts
Document Length:        3631 bytes

Concurrency Level:      5
Time taken for tests:   4.082 seconds
Complete requests:      1000
Failed requests:        0
Total transferred:      4286000 bytes
HTML transferred:       3631000 bytes
Requests per second:    244.99 [#/sec] (mean)
Time per request:       20.409 [ms] (mean)
Time per request:       4.082 [ms] (mean, across all concurrent requests)
Transfer rate:          1025.42 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.1      0       2
Processing:     7   20   6.9     19      51
Waiting:        6   20   6.9     19      49
Total:          7   20   6.9     19      51

Percentage of the requests served within a certain time (ms)
  50%     19
  66%     22
  75%     24
  80%     26
  90%     30
  95%     33
  98%     38
  99%     41
 100%     51 (longest request)
```
 
# Ruby 2.5.0 with Coverband

This is with 100% coverage