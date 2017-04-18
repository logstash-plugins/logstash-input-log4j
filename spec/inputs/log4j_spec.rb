# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "socket"
require "logstash/inputs/log4j"
require "logstash/plugin"
require "stud/try"
require "stud/task"
require 'timeout'
require "flores/random"

# Uncomment to enable higher level logging if needed during testing.
#LogStash::Logging::Logger::configure_logging("DEBUG")

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

  context "integration test" do
    let(:host) { "127.0.0.1" }
    let(:port) do
      socket, address, port = Flores::Random.tcp_listener
      socket.close
      port
    end

    let(:config) do
      {
        "host" => host,
        "port" => port
      }
    end

    subject { LogStash::Inputs::Log4j.new(config) }

    before do
      subject.register
    end

    let(:thread) do
      Thread.new { subject.run(queue) }
    end

    let(:queue) do
      []
    end

    let(:client) do
      Stud.try(5.times) { TCPSocket.new(host, port) }
    end

    after do
      subject.do_stop

      10.times do 
        break unless thread.alive?
        sleep(0.1)
      end
      expect(thread).not_to be_alive
    end

    shared_examples "accept events from the network" do |fixture|
      before do
        thread  # make the thread run
        File.open(fixture, "rb") do |payload|
          IO.copy_stream(payload, client)
        end
        client.close

        Stud.try(5.times) do
          throw StandardError.new("queue was empty, no data?") if queue.empty?
        end
        expect(queue.size).to be == 1
      end

      it "should accept an event from the network" do
        event = queue.first
        expect(event.get("message")).to be == "Hello world"
      end
    end

    context "default behavior" do
      include_examples "accept events from the network", "spec/fixtures/log4j.payload"
    end

    context "with proxy enabled" do
      let(:config) do
        {
          "host" => host,
          "port" => port,
          "proxy_protocol" => true
        }
      end

      before do
        client.write("PROXY TCP4 1.2.3.4 5.6.7.8 1234 5678\r\n")
      end

      include_examples "accept events from the network", "spec/fixtures/log4j.payload" do
        it "should set proxy_host and proxy_port" do
          event = queue.first
          expect(event.get("host")).to be == "1.2.3.4"
        end
      end
    end
  end

  context "for safety" do
    let(:input) { java.lang.Integer.new(Flores::Random.integer(0..1000)) }
    let(:baos) { java.io.ByteArrayOutputStream.new }
    let(:oos) { java.io.ObjectOutputStream.new(baos) }
    let(:data) {
      oos.writeObject(input)
      baos.toByteArray()
    }

    let(:bais) { java.io.ByteArrayInputStream.new(data) }
    let(:ois) { LogStash::Inputs::Log4j::Log4jInputStream.new(bais) }

    it "should reject non-log4j objects" do
      expect { ois.readObject }.to raise_error(java.io.InvalidObjectException)
    end
  end
end
