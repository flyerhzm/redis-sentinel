require "spec_helper"
require "em-synchrony/redis-sentinel"
require "eventmachine"

describe Redis::Client do
  context "#auto_retry_with_timeout" do
    subject { described_class.new(:failover_reconnect_timeout => 3,
                                :failover_reconnect_wait => 0.1) }
    context "configured wait time" do

      it "uses the wait time and blocks em" do
        allow(Time).to receive(:now).and_return(100, 101, 105)
        flag = false; EM.next_tick { flag = true }
        expect(subject).to receive(:sleep).with(0.1).and_return(0.1)
        begin
          subject.auto_retry_with_timeout { raise Redis::CannotConnectError }
        rescue Redis::CannotConnectError
        end
        expect(flag).to be_false
      end

      it "uses the wait time and doesn't block em" do
        allow(Time).to receive(:now).and_return(100, 101, 105)
        flag = false; EM.next_tick { flag = true }
        begin
          subject.auto_retry_with_timeout { raise Redis::CannotConnectError }
        rescue Redis::CannotConnectError
        end
        expect(flag).to be_true
      end
    end
  end

  around(:each) do |testcase|
    EM.run do
      Fiber.new do
        begin
          testcase.call
        ensure
          EM.stop
        end
      end.resume
    end
  end
end
