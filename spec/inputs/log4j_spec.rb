# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "socket"
require "logstash/inputs/log4j"
require "logstash/plugin"
require "stud/try"
require "stud/task"

describe LogStash::Inputs::Log4j do

  it "should register" do
    plugin = LogStash::Plugin.lookup("input", "log4j").new("mode" => "client")


    # register will try to load jars and raise if it cannot find jars or if org.apache.log4j.spi.LoggingEvent class is not present
    expect {plugin.register}.to_not raise_error
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
        allow(subject).to receive(:build_client_socket).and_return(socket)
        expect(subject).to receive(:socket_to_inputstream).with(socket).and_return(ois)
        expect(subject).to receive(:create_event).and_return(LogStash::Event.new).at_least(:once)
      end
    end
  end

  context "reading general information from a org.apache.log4j.spi.LoggingEvent" do
    let (:plugin) { LogStash::Plugin.lookup("input", "log4j").new("mode" => "client") }
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
      subject = plugin.create_event(log_obj)
      expect(subject.get("timestamp")).to eq(1426366971)
      expect(subject.get("path")).to eq("org.apache.log4j.LayoutTest")
      expect(subject.get("priority")).to eq("INFO")
      expect(subject.get("logger_name")).to eq("org.apache.log4j.LayoutTest")
      expect(subject.get("thread")).to be_a(String)
      expect(subject.get("thread")).not_to be_empty
      expect(subject.get("message")).to eq("Hello, World")
      # checks locationInformation is collected, but testing exact values is not meaningful in jruby
      expect(subject.get("class")).not_to be_empty
      expect(subject.get("file")).not_to be_empty
      expect(subject.get("method")).not_to be_empty
    end

    it "creates event without stacktrace" do
      subject = plugin.create_event(log_obj)
      expect(subject.get("stack_trace")).to be_nil
    end

    it "creates event with stacktrace" do
      subject = plugin.create_event(log_obj_with_stacktrace)
      #checks stack_trace is collected, exact value is too monstruous
      expect(subject.get("stack_trace")).not_to be_empty
    end
  end

  context "full socket tests" do
	it "should instantiate with port and let us send content" do
      p "starting my test"
      port = rand(1024..65535)

      conf = <<-CONFIG
        input {
          log4j {
            mode => "server"
            port => #{port}
          }
        }
      CONFIG
      p conf

      p "before pipeline"
      events = input(conf) do |pipeline, queue|

        p "before socket"
        socket = Stud::try(5.times) { TCPSocket.new("127.0.0.1", port) }
        data = File.read("testdata/log4j.capture")
        socket.puts(data)
        socket.flush
        socket.close

        #p "before collect"
        #1.times.collect { queue.pop }
      end
      p "after pipeline"

      p "after loop"
      insist { events.length } == 1 
      insist { events[0].get("logger_name") } == "sender"
    end
  end
end
