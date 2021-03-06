# This spec covers the question here:
# https://groups.google.com/forum/?fromgroups=#!topic/logstash-users/Ec8ISgamIfo

require "test_utils"

describe "https://groups.google.com/forum/?fromgroups=#!topic/logstash-users/Ec8ISgamIfo" do
  extend LogStash::RSpec

  config <<-'CONFIG'
    filter {
      multiline {
        type => "java-log"
        pattern => "^20"
        negate => "true"
        what => "previous"
      }
      grok {
        type => "java-log"
        tags => [ "dev", "console", "multiline" ]
        singles => true
        add_tag => "mytag"
        match => [ "@message", "^%{DATESTAMP:log_time}%{SPACE}\[%{PROG:thread}\]%{SPACE}%{LOGLEVEL:log_level}%{SPACE}%{WORD:class_name}%{GREEDYDATA}"]
      }
    }
  CONFIG

  type "java-log"
  tags "dev", "console"
 
  line1 = '2012-11-13 13:55:37,706 [appname.connector.http.mule.default.receiver.14] INFO  LoggerMessageProcessor -  SRC message is <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:icc="http://researchnow.com/schema/icc"'
  line2 = "hello world"

  sample line1 do
    insist { subject.tags }.include?("dev")
    insist { subject.tags }.include?("console")

    # This is not a multiline event, so it won't get tagged as multiline
    reject { subject.tags }.include?("multiline")

    # Since this event doesn't have the 'multiline' tag, grok will not act on
    # it, so it should not have the 'mytag' tag given in the grok filter's
    # add_tag setting.
    reject { subject.tags }.include?("mytag")
  end

  # Try with a proper multiline event
  sample [ line1, line2 ] do
    reject { subject }.is_a? Array

    insist { subject.tags }.include?("dev")
    insist { subject.tags }.include?("console")
    insist { subject.tags }.include?("multiline")

    # grok shouldn't fail.
    reject { subject.tags }.include?("_grokparsefailure")

    # Verify grok is working and pulling out certain fields
    insist { subject.tags }.include?("mytag")
    insist { subject["log_time"] } == "2012-11-13 13:55:37,706"
    insist { subject["thread"] } == "appname.connector.http.mule.default.receiver.14"
    insist { subject["log_level"] } == "INFO"
    insist { subject["class_name"] } == "LoggerMessageProcessor"
  end
end
