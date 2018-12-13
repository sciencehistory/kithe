require 'rails_helper'

describe "Kithe::ConfigBase" do
  let(:test_key) { :some_key }
  let(:env_value) { "env_value" }
  let(:conf_value) { "conf_value" }
  let(:default_value) { "default_value"}

  let(:config_class) do
    # hack to get accessible in closure
    Class.new(Kithe::ConfigBase).tap do |klass|
      klass.define_key test_key, default: default_value
    end
  end

  it "raises on unrecognized key" do
    expect { config_class.lookup("no_such_key") }.to raise_error(ArgumentError)
  end

  describe "from ENV" do
    before do
      stub_const('ENV', ENV.to_hash.merge(test_key.to_s.upcase => env_value))
      allow(config_class.instance).to receive(:load_from_files!).and_return(test_key.to_s => conf_value)
    end

    it "takes priority" do
      expect(config_class.lookup(test_key)).to eq(env_value)
    end

    describe "with env_key: false" do
      before do
        config_class.define_key test_key, default: default_value, env_key: false
      end
      it "disables env lookup" do
        expect(config_class.lookup(test_key)).to eq(conf_value)
      end
    end

    describe "with custom env_key" do
      before do
        stub_const('ENV', ENV.to_hash.merge("new_env_key" => "new_env_key_value"))
        config_class.define_key test_key, default: default_value, env_key: "new_env_key"
      end
      it "finds from specified env key" do
        expect(config_class.lookup(test_key)).to eq("new_env_key_value")
      end
    end

    describe "boolean transform from ENV" do
      before do
        stub_const('ENV', ENV.to_hash.merge(test_key.to_s.upcase => "true"))
        config_class.define_key test_key, default: default_value, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM
      end

      it "converts to boolean" do
        expect(config_class.lookup(test_key)).to eq true
      end
    end

    describe "custom transform from ENV" do
      before do
        stub_const('ENV', ENV.to_hash.merge(test_key.to_s.upcase => "101"))
        config_class.define_key test_key, default: default_value, system_env_transform: ->(str) { Integer(str) }
      end

      it "converts to boolean" do
        expect(config_class.lookup(test_key)).to eq 101
      end
    end
  end

  describe "from conf files" do
    let(:config1) do
      Tempfile.new("config1").tap do |file|
        file.write(<<~EOS)
          key1: from_config1
          key2: from_config1
          key3: from_config1
          boolean_false: false
          boolean_true: true
        EOS
        file.rewind
      end
    end
    let(:config2) do
      Tempfile.new("config1").tap do |file|
        file.write("key2: from_config2\nkey3: from_config2")
        file.rewind
      end
    end
    before do
      stub_const('ENV', ENV.to_hash.merge("KEY3" => "from_env"))

      config_class.define_key :key1
      config_class.define_key :key2
      config_class.define_key :key3
      config_class.config_file [config1.path, config2.path]
    end

    it "returns from conf files with proper priority" do
      expect(config_class.lookup("key1")).to eq("from_config1")
      expect(config_class.lookup("key2")).to eq("from_config2")
      expect(config_class.lookup("key3")).to eq("from_env")
    end

    describe "with boolean values in config file" do
      let(:config1) do
        Tempfile.new("config1").tap do |file|
          file.write(<<~EOS)
            boolean_false: false
            boolean_true: true
          EOS
          file.rewind
        end
      end
      before do
        config_class.define_key :boolean_false, default: true
        config_class.define_key :boolean_true, default: false
        config_class.define_key :boolean_default_true, default: true
        config_class.define_key :boolean_missing
      end

      it "retrieves true value from config" do
        expect(config_class.lookup("boolean_true")).to eq true
      end

      it "retrieves false value from conf, despite default" do
        expect(config_class.lookup("boolean_false")).to eq false
      end

      it "applies default when missing" do
        expect(config_class.lookup("boolean_default_true")).to eq true
      end

      it "returns nil for no value" do
        expect(config_class.lookup("boolean_missing")).to be_nil
      end
    end
  end

  describe "from defaults" do
    it "returns simple default" do
      expect(config_class.lookup(test_key)).to eq(default_value)
    end

    describe "with proc" do
      before do
        config_class.define_key test_key, default: -> { "default_from_lambda" }
      end
      it "returns lambda result" do
        expect(config_class.lookup(test_key)).to eq("default_from_lambda")
      end
    end
  end

  describe "allowable" do
    describe "regexp" do
      before do
        config_class.define_key "with_allowance", allows: /a/
      end
      it "allows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "this has a"))
        expect(config_class.lookup("with_allowance")).to eq("this has a")
      end
      it "disallows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "does not"))
        expect { config_class.lookup("with_allowance") }.to raise_error(TypeError)
      end
    end
    describe "proc" do
      before do
        config_class.define_key "with_allowance", allows: ->(val) { val != "bad" }
      end
      it "allows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "okay"))
        expect(config_class.lookup("with_allowance")).to eq("okay")
      end
      it "disallows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "bad"))
        expect { config_class.lookup("with_allowance") }.to raise_error(TypeError)
      end
    end
    describe "array" do
      before do
        config_class.define_key "with_allowance", allows: ["this has a", "other thing"]
      end
      it "allows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "this has a"))
        expect(config_class.lookup("with_allowance")).to eq("this has a")
      end
      it "disallows" do
        stub_const('ENV', ENV.to_hash.merge("WITH_ALLOWANCE" => "not allowed thing"))
        expect { config_class.lookup("with_allowance") }.to raise_error(TypeError)
      end
    end
  end

  describe "#lookup!" do
    before do
      config_class.define_key "no_value_provided"
    end
    it "raises on no value provided" do
      expect { config_class.lookup!("no_value_provided")}.to raise_error(TypeError)
    end
  end

  describe "default in terms of another value" do
    let(:config_class) do
      Class.new(Kithe::ConfigBase).tap do |klass|
        klass.define_key "base_key"
        klass.define_key "derived_key", default: -> { "derived: #{lookup("base_key")}" }
      end
    end

    before do
      stub_const('ENV', ENV.to_hash.merge("BASE_KEY" => "value from env"))
    end

    it "works" do
      expect(config_class.lookup("derived_key")).to eq("derived: value from env")
    end
  end
end
