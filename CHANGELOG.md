# 2.0.7
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.6
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.5
 - Fix a spec that was incompatible with the ng pipeline
## 2.0.4
 - Bump for LS 2.x compatibility
## 2.0.3
 - Refactor code to improve test reliability
## 2.0.2
 - Fix tests with `Thread.abort_on_exception` turn on
## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully, 
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

# 1.0.1
  - refactor test to allow unit testing of logstash event creation
