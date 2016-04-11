require 'spec_helper'

describe RealCerealBusiness::DocumentCache do

  describe ".fetch" do
    let(:facade) { RealCerealBusiness::Serializer::Facade.new(serializer, resource, options)}
    let(:options) { make_options({fields: [:basic, :children, :master]}) }
    let(:resource) { create :resource_a, :with_children, :with_master }
    let(:cache_opts) { { force: force } }
    let(:force) { false }
    let(:serializer) { V1::ResourceA::ResourceASerializer.new }

    let(:natural_result) { { a: :b } }
    let(:cached_result) { { c: :d } }
    let(:fetched_result) { { c: :d } }

    subject { described_class.fetch(facade, cache_opts) { natural_result } }
    let(:cached_subject) { described_class.fetch(facade) { cached_result } }
    let(:fetched_subject) { described_class.fetch(facade) { fetched_result } }

    before do
      temp = RealCerealBusiness.cache_enabled
      RealCerealBusiness.cache_enabled = true
      cached_subject
      RealCerealBusiness.cache_enabled = temp
    end

    context "cache disabled" do
      it { expect(subject).to eq( natural_result ) }
      it { expect(cached_subject).to eq( cached_result ) }
      it { expect(fetched_subject).to eq( fetched_result ) }
    end

    context "cache enabled" do
      before do
        temp = RealCerealBusiness.cache_enabled
        RealCerealBusiness.cache_enabled = true
        subject
        RealCerealBusiness.cache_enabled = temp
      end

      it { expect(subject).to eq( cached_result ) }
      it { expect(cached_subject).to eq( cached_result ) }
      it { expect(fetched_subject).to eq( cached_result ) }

      context "forced" do
        context "context" do
          let(:force) { true }
          it { expect(subject).to eq( natural_result ) }
          it { expect(cached_subject).to eq( cached_result ) }
          it { expect(fetched_subject).to eq( fetched_result ) }
        end
        context "configuration" do
          around do |example|
            Rails.cache.clear
            temp = RealCerealBusiness::default_cache_options
            RealCerealBusiness::default_cache_options = { force: true }
            example.run
            RealCerealBusiness::default_cache_options = temp
          end
          it { expect(subject).to eq( natural_result ) }
          it { expect(cached_subject).to eq( cached_result ) }
          it { expect(fetched_subject).to eq( fetched_result ) }
        end
      end

      context "miss" do
        before do
          allow(described_class).to receive(:digest_key).and_return("a", "b")
          subject
        end
        it { expect(subject).to eq( natural_result ) }
        it { expect(fetched_subject).to eq( fetched_result ) }
      end
    end

    # # Fetches a JSON document representing the facade
    # # @param facade [Object] to cache
    # # @param options [Hash] for Rails.cache.fetch
    # # @param &block [Proc] for cache miss
    # # @return [Object]
    # def self.fetch(facade, options = {})
    #   return yield unless cacheable?(facade)

    #   options[:force] ||= facade.opts[RealCerealBusiness.cache_force_key]
    #   cache_key = digest_key(facade)
    #   if options[:force] || !(result = Rails.cache.fetch(cache_key))
    #     result = yield
    #     Rails.cache.write(cache_key, ::Oj.dump(result), RealCerealBusiness::default_cache_options.merge(options))
    #     result
    #   else
    #     ::Oj.load(result)
    #   end
    # end
  end

  describe ".fetch_association" do
    # #TODO --jdc implement
    # yield
  end

  describe ".digest_key" do
      # Salts and hashes facade cache_key
    # @param facade [Facade] to generate key for
    # @return [String]
    # def self.digest_key(facade)
    #   Digest::MD5.hexdigest(CACHE_PREFIX + facade.cache_key.to_s)
    # end
  end

  describe ".cacheable?" do
    # Tells if the resource to be serialized can be cached
    # @param facade [Facade] to inspect
    # @return [Boolean]
    # def self.cacheable?(facade)
    #   RealCerealBusiness.cache_enabled
    # end
  end
end