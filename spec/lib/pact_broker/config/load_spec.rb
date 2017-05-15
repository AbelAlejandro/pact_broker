require 'pact_broker/config/load'

module PactBroker
  module Config
    describe Load do

      describe ".call" do

        class MockConfig
          attr_accessor :foo, :bar, :nana, :meep, :lalala, :meow, :peebo
        end

        let(:configuration) { MockConfig.new }
        before do
          Setting.create(name: 'foo', type: 'JSON', value: {"a" => "thing"}.to_json)
          Setting.create(name: 'bar', type: 'String', value: "bar")
          Setting.create(name: 'nana', type: 'Integer', value: "1")
          Setting.create(name: 'meep', type: 'Float', value: "1.2")
          Setting.create(name: 'lalala', type: 'Boolean', value: "1")
          Setting.create(name: 'meow', type: 'Boolean', value: "0")
          Setting.create(name: 'peebo', type: 'String', value: nil)
          Setting.create(name: 'unknown', type: 'String', value: nil)
        end

        subject { Load.call(configuration) }

        it "loads a JSON config" do
          subject
          expect(configuration.foo).to eq(a: "thing")
        end

        it "loads a String setting" do
          subject
          expect(configuration.bar).to eq "bar"
        end

        it "loads an Integer setting" do
          subject
          expect(configuration.nana).to eq 1
        end

        it "loads a Float setting" do
          subject
          expect(configuration.meep).to eq 1.2
        end

        it "loads a true setting" do
          subject
          expect(configuration.lalala).to eq true
        end

        it "loads a false setting" do
          subject
          expect(configuration.meow).to eq false
        end

        it "loads a nil setting" do
          subject
          expect(configuration.peebo).to eq nil
        end

        it "does not load a setting where the Configuration object does not have a matching property" do
          allow(Load.logger).to receive(:warn)
          expect(Load.logger).to receive(:warn).with("Could not load configuration setting \"unknown\" as there is no matching attribute on the Configuration class")
          subject
        end
      end
    end
  end
end
