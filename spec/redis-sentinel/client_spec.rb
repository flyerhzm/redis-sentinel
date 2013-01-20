require "spec_helper"

describe Redis::Client do
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
    let(:client) { Redis::Client.new(:master_name => "master", :sentinels => [{:host => "localhost", :port => 26379}, {:host => "localhost", :port => 26380}]) }

    it "should return next sentinel server" do
      expect(client.try_next_sentinel).to eq({:host => "localhost", :port => 26380})
    end
  end

  context "#discover_master" do
    let(:client) { Redis::Client.new(:master_name => "master", :sentinels => [{:host => "localhost", :port => 26379}, {:host => "localhost", :port => 26380}]) }
    before { Redis.any_instance.should_receive(:sentinel).with("get-master-addr-by-name", "master").and_return(["remote.server", 8888]) }

    it "should update options" do
      client.discover_master
      expect(client.host).to eq "remote.server"
      expect(client.port).to eq 8888
    end
  end
end
