require "spec_helper"

describe Redis::Client do
  let(:redis) { mock("Redis", :sentinel => ["remote.server", 8888])}

  subject { Redis::Client.new(:master_name => "master",
                              :sentinels => [{:host => "localhost", :port => 26379},
                                             {:host => "localhost", :port => 26380}]) }

  before { Redis.stub(:new).and_return(redis) }

  context "#sentinel?" do
    it "should be true if passing sentiels and master_name options" do
      expect(Redis::Client.new(:master_name => "master", :sentinels => [{:host => "localhost", :port => 26379}, {:host => "localhost", :port => 26380}])).to be_sentinel
    end

    it "should not be true if not passing sentinels and maser_name options" do
      expect(Redis::Client.new).not_to be_sentinel
    end

    it "should not be true if passing sentinels option but not master_name option" do
      expect(Redis::Client.new(:sentinels => [{:host => "localhost", :port => 26379}, {:host => "localhost", :port => 26380}])).not_to be_sentinel
    end

    it "should not be true if passing master_name option but not sentinels option" do
      expect(Redis::Client.new(:master_name => "master")).not_to be_sentinel
    end
  end

  context "#try_next_sentinel" do
    it "should return next sentinel server" do
      expect(subject.try_next_sentinel).to eq({:host => "localhost", :port => 26380})
    end
  end

  context "#discover_master" do
    it "gets the current master" do
      redis.should_receive(:sentinel).
            with("get-master-addr-by-name", "master")
      subject.discover_master
    end

    it "should update options" do
      subject.discover_master
      expect(subject.host).to eq "remote.server"
      expect(subject.port).to eq 8888
    end

    describe "memoizing sentinel connections" do
      it "does not reconnect to the sentinels" do
        Redis.should_receive(:new).once

        subject.discover_master
        subject.discover_master
      end
    end
  end
end
