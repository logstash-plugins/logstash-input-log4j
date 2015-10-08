# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/log4j"
require "logstash/plugin"

Thread.abort_on_exception = true
describe LogStash::Inputs::Log4j do

  it "should register" do
    input = LogStash::Plugin.lookup("input", "log4j").new("mode" => "client")


    # register will try to load jars and raise if it cannot find jars or if org.apache.log4j.spi.LoggingEvent class is not present
    expect {input.register}.to_not raise_error
  end

  context "when interrupting the plugin in server mode" do
    let(:config) { { "mode" =>  "server" } }
    it_behaves_like "an interruptible input plugin"
  end

  context "when interrupting the plugin in client mode" do
    it_behaves_like "an interruptible input plugin" do
      let(:config) { { "mode" =>  "client" } }
      let(:socket) { double("socket") }
      let(:ois)    { double("ois") }
      before(:each) do
        allow(socket).to receive(:peer).and_return("localhost")
        allow(socket).to receive(:close).and_return(true)
        allow(ois).to receive(:readObject).and_return({})
        allow(TCPSocket).to receive(:new).and_return(socket)
        expect(subject).to receive(:socket_to_inputstream).with(socket).and_return(ois)
        expect(subject).to receive(:create_event).and_return(LogStash::Event.new).at_least(:once)
      end
    end
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
