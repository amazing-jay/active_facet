require 'spec_helper'

describe ActiveFacet do

  describe 'has a version number' do
    it { expect(ActiveFacet::VERSION).not_to be nil }
  end

  describe 'sets defaults for configuration settings' do
    it { expect(described_class.default_version).to                eq( 1.0 ) }
    it { expect(described_class.opts_key).to                       eq( :af_opts ) }
    it { expect(described_class.fields_key).to                     eq( :fields ) }
    it { expect(described_class.field_overrides_key).to            eq( :field_overrides ) }
    it { expect(described_class.version_key).to                    eq( :version ) }
    it { expect(described_class.filters_key).to                    eq( :filters ) }
    it { expect(described_class.cache_bypass_key).to               eq( :cache_bypass ) }
    it { expect(described_class.cache_force_key).to                eq( :cache_force ) }
    it { expect(described_class.filters_force_key).to              eq( :filters_force ) }

    it { expect(described_class.strict_lookups).to                 eq( false ) }
    it { expect(described_class.preload_associations).to           eq( false ) }
    it { expect(described_class.filters_enabled).to                eq( false ) }
    it { expect(described_class.cache_enabled).to                  eq( false ) }
    it { expect(described_class.acts_as_active_facet_enabled).to   eq( false ) }
    it { expect(described_class.default_cache_options).to          eq( { expires_in: 5.minutes } ) }
    it { expect(described_class.document_cache).to                 eq( ActiveFacet::DocumentCache ) }
  end

  describe 'configure' do
    subject { described_class.configure { } }
    before do
      allow(ActiveRecord::Base).to receive(:acts_as_active_facet).and_call_original
      subject
    end

    context 'without acts_as_active_facet' do
      it { expect(ActiveRecord::Base).to_not have_received(:acts_as_active_facet) }
    end

    context 'with acts_as_active_facet' do
      subject { described_class.configure { |config| config.acts_as_active_facet_enabled = true } }
      it { expect(ActiveRecord::Base).to have_received(:acts_as_active_facet).once }
    end
  end

  describe 'global_filter' do
    subject { described_class.global_filter(name) { :foo } }
    let(:name) { :my_filter }
    before do
      allow(ActiveFacet::Filter).to receive(:register_global).and_call_original
      subject
    end
    it { expect(ActiveFacet::Filter).to have_received(:register_global).once }
  end

  describe 'resource_mapper' do
    subject { described_class.resource_mapper { :foo } }
    before do
      allow(ActiveFacet::Helper).to receive(:resource_mapper=).and_call_original
      subject
    end
    it { expect(ActiveFacet::Helper).to have_received(:resource_mapper=).once }
  end

  describe 'serializer_mapper' do
    subject { described_class.serializer_mapper { :foo } }
    before do
      allow(ActiveFacet::Helper).to receive(:serializer_mapper=).and_call_original
      subject
    end
    it { expect(ActiveFacet::Helper).to have_received(:serializer_mapper=).once }
  end

  describe 'fields_from_options' do
    subject { described_class.fields_from_options(options) }
    let(:fields) { :hello }

    context "empty" do
      let(:options) { {} }
      it { expect(subject).to eq(nil) }
    end

    context "nested empty" do
      let(:options) { make_options({}) }
      it { expect(subject).to eq(nil) }
    end

    context "present" do
      let(:options) { make_options fields: fields }
      it { expect(subject).to eq(:hello) }
    end
  end

  describe 'options_with_fields' do
    subject { described_class.options_with_fields(options, fields) }
    let(:fields) { :hello }

    context "empty" do
      let(:options) { {} }
      it { expect(subject).to eq({:af_opts=>{:fields=>:hello}}) }
    end

    context "nested empty" do
      let(:options) { make_options({}) }
      it { expect(subject).to eq({:af_opts=>{:fields=>:hello, :field_overrides=>nil, :version=>nil, :filters=>nil}}) }
    end

    context "present" do
      let(:options) { make_options fields: :whatnot }
      it { expect(subject).to eq({:af_opts=>{:fields=>:hello, :field_overrides=>nil, :version=>nil, :filters=>nil}}) }
    end
  end

  describe 'restore_opts_after' do
    subject { described_class.restore_opts_after(options, key, value) {
      options[ActiveFacet.opts_key][key] = value
      :return_value
    } }
    let(:options) { make_options(key => original_value) }
    let(:key) { :fields }
    let(:value) { :bar }
    let(:original_value) { :foo }

    it { expect(subject).to eq(:return_value) }
    it { expect(options[ActiveFacet.opts_key][key]).to eq(original_value) }
  end

  describe ".deep_copy" do
    let(:obj) { { a: [:b,:c], d: { e: :f } } }
    subject { described_class.deep_copy(obj) }
    before do
      subject[:d][:e] = :g
    end
    it { expect(obj).to eq({ a: [:b,:c], d: { e: :f } }) }
    it { expect(subject).to eq({ a: [:b,:c], d: { e: :g } }) }
  end

end