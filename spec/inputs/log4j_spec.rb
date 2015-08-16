# encoding: utf-8

require "logstash/plugin"

describe "inputs/log4j" do

  it "should register" do
    input = LogStash::Plugin.lookup("input", "log4j").new("mode" => "client")

    # register will try to load jars and raise if it cannot find jars or if org.apache.log4j.spi.LoggingEvent class is not present
    expect {input.register}.to_not raise_error
  end

  context "reading general information from a org.apache.log4j.spi.LoggingEvent" do
    let (:input) { LogStash::Plugin.lookup("input", "log4j").new("mode" => "client") }
    let (:log_obj) {
      org.apache.log4j.spi.LoggingEvent.new(
        "org.apache.log4j.Logger",
        org.apache.log4j.Logger.getLogger("org.apache.log4j.LayoutTest"),
        1426366971,
        org.apache.log4j.Level::INFO,
        "Hello, World",
        nil
      )
    }

    let (:log_obj_with_stacktrace) {
      org.apache.log4j.spi.LoggingEvent.new(
        "org.apache.log4j.Logger",
        org.apache.log4j.Logger.getLogger("org.apache.log4j.LayoutTest"),
        1426366971,
        org.apache.log4j.Level::INFO,
        "Hello, World",
        java.lang.IllegalStateException.new()
      )
    }

    it "creates event with general information" do
      subject = input.create_event(log_obj)
      expect(subject["timestamp"]).to eq(1426366971)
      expect(subject["path"]).to eq("org.apache.log4j.LayoutTest")
      expect(subject["priority"]).to eq("INFO")
      expect(subject["logger_name"]).to eq("org.apache.log4j.LayoutTest")
      expect(subject["thread"]).to eq("main")
      expect(subject["message"]).to eq("Hello, World")
      # checks locationInformation is collected, but testing exact values is not meaningful in jruby
      expect(subject["class"]).not_to be_empty
      expect(subject["file"]).not_to be_empty
      expect(subject["method"]).not_to be_empty
    end

    it "creates event without stacktrace" do
      subject = input.create_event(log_obj)
      expect(subject["stack_trace"]).to be_nil
    end

    it "creates event with stacktrace" do
      subject = input.create_event(log_obj_with_stacktrace)
      #checks stack_trace is collected, exact value is too monstruous
      expect(subject["stack_trace"]).not_to be_empty
    end
  end
end
