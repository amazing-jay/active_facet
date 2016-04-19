require 'spec_helper'

describe ActiveFacets::Filter do

  let(:basic_class) { Class.new }
  let(:acts_as_class) { Class.new { include ActiveFacets::ActsAsActiveFacet; acts_as_active_facet } }
  let(:inherited_acts_as_class) { Class.new(basic_class) { include ActiveFacets::ActsAsActiveFacet; acts_as_active_facet } }
  let(:inherited_class) { Class.new(inherited_acts_as_class) }
  let(:double_inherited_class) { Class.new(inherited_class) }


  describe "public attributes" do
    it { expect(described_class.filters).to eq({}) }
    it { expect(described_class.registered_filters).to eq({}) }
    it { expect(described_class.global_filters).to eq({}) }
  end

  describe "register_global" do
    subject { described_class.register_global(filter_name, filter_method) }
    let(:filter_name) { :foo }
    let(:filter_method) { Proc.new { :bar } }
    before do
      subject
    end
    it { expect(subject).to eq(filter_method) }
    it { expect(described_class.global_filters[filter_name]).to eq(filter_method) }

    context "filter name as string" do
      let(:filter_name) { 'foo' }
      it { expect(subject).to eq(filter_method) }
      it { expect(described_class.global_filters[filter_name.to_sym]).to eq(filter_method) }
    end
  end

  describe "register" do
    subject { described_class.register(receiver, filter_name, filter_method_name) }
    let(:receiver) { basic_class }
    let(:filter_name) { :foo }
    let(:filter_method_name) { :bar }

    it { expect{subject}.to raise_error(ActiveFacets::Errors::ConfigurationError,ActiveFacets::Errors::ConfigurationError::ACTS_AS_ERROR_MSG) }

    context "filterable" do
      let(:receiver) { acts_as_class }
      before do
        subject
      end

      it { expect(subject).to eq(receiver) }
      it { expect(described_class.filters[receiver.name]).to include({filter_name.to_sym => filter_method_name.to_sym})}
    end
  end

  describe "apply_globals_to" do
    subject { described_class.apply_globals_to(receiver) }
    let(:receiver) { basic_class }
    before do
      described_class.register_global(:foo, Proc.new { :bar } )
      described_class.register_global(:alpha, :century)
      allow(receiver).to receive(:facet_filter).and_call_original
    end

    it { expect{subject}.to raise_error(ActiveFacets::Errors::ConfigurationError,ActiveFacets::Errors::ConfigurationError::ACTS_AS_ERROR_MSG) }

    context "filterable" do
      let(:receiver) { acts_as_class }
      before do
        subject
      end

      it { expect(subject).to eq(receiver) }
      it { expect(receiver).to have_received(:facet_filter).twice }
      it { expect(receiver.methods).to include(:registered_filter_foo) }
      it { expect(receiver.registered_filter_foo).to eq(:bar) }
    end
  end

  describe "registered_filters_for" do
    let(:receiver) { acts_as_class }
    subject { described_class.registered_filters_for(receiver) }

    before do
      described_class.register(receiver, :foo, :bar)
      described_class.register(receiver, :alpha, :century)
      allow(described_class).to receive(:registered_filters_for).and_call_original
    end

    context "basic" do
      before do
        subject
      end

      it { expect(subject).to eq({:foo=>:bar, :alpha=>:century})}
    end

    context "memoized" do
      before do
        described_class.registered_filters_for(receiver)
        subject
      end
      it { expect(described_class).to have_received(:registered_filters_for).twice }
    end

    context "inherited" do
      let(:receiver) { double_inherited_class }

      before do
        described_class.register(inherited_acts_as_class, :marco, :pollo)
        subject
      end

      it { expect(described_class).to have_received(:registered_filters_for).once }
      it { expect(subject).to eq({:foo=>:bar, :alpha=>:century, :marco=>:pollo})}
    end
  end

  describe "filterable?" do
    subject { described_class.filterable?(receiver) }
    let(:receiver) { acts_as_class }

    context "basic" do
      let(:inheritable_class) { Class.new { include ActiveFacets::ActsAsActiveFacet; acts_as_active_facet } }
      it { expect(subject).to be true }
    end

    context "inherited" do
      it { expect(subject).to be true }
    end

    context "not included" do
      let(:receiver) { Class.new }
      it { expect(subject).to be false }
    end
  end
end