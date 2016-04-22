require 'spec_helper'

describe ActiveFacet::ActsAsActiveFacet do

  let(:serializer) { V1::ResourceA::ResourceASerializer.instance }
  let(:serializer2) { V2::ResourceA::ResourceASerializer.instance }
  let(:receiver) { ResourceA }
  let(:method_aliases) { {
      includes_method_name:       :includes_method_name,
      apply_includes_method_name: :apply_includes_method_name,
      filter_method_name:         :filter_method_name,
      apply_filters_method_name:  :apply_filters_method_name,
      unserialize_method_name:    :unserialize_method_name,
      serialize_method_name:      :serialize_method_name
    } }
  before do
    reset_filter_memoization
  end

  describe "acts_as_active_facet" do
    subject { receiver.acts_as_active_facet(options) }
    let(:receiver) { Class.new { include ActiveFacet::ActsAsActiveFacet } }
    let(:options) { {} }

    it { expect(receiver.instance_methods).to_not include(:from_json) }
    it { expect(receiver.methods).to_not include(
      :acts_as_active_facet_options,
      :facet_includes,
      :apply_facet_includes,
      :facet_filter,
      :apply_facet_filters,
      :from_json
    )}

    context "configuration error" do
      subject { receiver.acts_as_active_facet(options) }
      before do
        receiver.acts_as_active_facet(options)
      end
      it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError,ActiveFacet::Errors::ConfigurationError::DUPLICATE_ACTS_AS_ERROR_MSG) }
    end

    context "default" do
      before do
        subject
      end
      it { expect(receiver.instance_methods).to include(:from_json) }
      it { expect(receiver.methods).to include(
        :acts_as_active_facet_options,
        :facet_includes,
        :apply_facet_includes,
        :facet_filter,
        :apply_facet_filters,
        :from_json
      )}
      it { expect(receiver.acts_as_active_facet_options).to eq({
        includes_method_name:       :facet_includes,
        apply_includes_method_name: :apply_facet_includes,
        filter_method_name:         :facet_filter,
        apply_filters_method_name:  :apply_facet_filters,
        unserialize_method_name:    :from_json,
        serialize_method_name:      :as_json
      }) }
    end

    context "options" do
      before do
        subject
      end
      let(:options) { method_aliases }
      it { expect(receiver.instance_methods).to include(:unserialize_method_name, :serialize_method_name) }
      it { expect(receiver.methods).to include(
        :acts_as_active_facet_options,
        :includes_method_name,
        :apply_includes_method_name,
        :filter_method_name,
        :apply_filters_method_name,
        :unserialize_method_name
      )}
      it { expect(receiver.acts_as_active_facet_options).to eq({
        includes_method_name:       :includes_method_name,
        apply_includes_method_name: :apply_includes_method_name,
        filter_method_name:         :filter_method_name,
        apply_filters_method_name:  :apply_filters_method_name,
        unserialize_method_name:    :unserialize_method_name,
        serialize_method_name:      :serialize_method_name
      }) }
    end
  end

  describe "dynamic methods" do
    describe "facet_includes" do
      subject { receiver.facet_includes(facets, options) }
      let(:options) { {} }
      let(:facets) { :all }
      before do
        allow(serializer).to receive(:scoped_includes).and_call_original
        allow(serializer2).to receive(:scoped_includes).and_call_original
        subject
      end
      it { expect(serializer).to have_received(:scoped_includes).with(facets) }
      it { expect(serializer2).to_not have_received(:scoped_includes).with(facets) }

      context "options" do
        let(:options) { make_options version: 2 }
        it { expect(serializer).to_not have_received(:scoped_includes).with(facets) }
        it { expect(serializer2).to have_received(:scoped_includes).with(facets) }
      end
    end

    describe "apply_facet_includes" do
      subject { receiver.apply_facet_includes(facets, options) }
      let(:scoped_includes) { serializer.scoped_includes(facets) }
      let(:options) { { foo: :bar } }
      let(:facets) { :all }
      before do
        allow(receiver).to receive(:facet_includes).and_call_original
        allow(receiver).to receive(:includes).and_call_original
        subject
      end
      it { expect(receiver).to have_received(:facet_includes).with(facets, options) }
      it { expect(receiver).to have_received(:includes).with(scoped_includes) }
    end

    describe "facet_filter" do
      subject { receiver.facet_filter(filter_name, filter_method_name) }
      let(:filter_name) { :foo }
      let(:filter_method_name) { :bar }
      before do
        allow(receiver).to receive(:define_singleton_method).and_call_original
        allow(ActiveFacet::Filter).to receive(:register).and_call_original
        subject
      end
      it { expect(receiver).to_not have_received(:define_singleton_method) }
      it { expect{receiver.send(filter_method_name)}.to raise_error(NoMethodError) }
      it { expect(ActiveFacet::Filter).to have_received(:register).with(receiver, filter_name, filter_method_name) }

      context "proc" do
        let(:filter_method_name) { Proc.new { :bar } }
        it { expect(receiver).to have_received(:define_singleton_method).once }
        it { expect(receiver.send('registered_filter_foo')).to eq(:bar) }
        it { expect(ActiveFacet::Filter).to have_received(:register).with(receiver, filter_name, "registered_filter_foo") }
      end

      context "block" do
        subject { receiver.facet_filter(filter_name, filter_method_name) { :alpha } }
        it { expect(receiver).to have_received(:define_singleton_method).once }
        it { expect(receiver.send(filter_method_name)).to eq(:alpha) }
        it { expect(ActiveFacet::Filter).to have_received(:register).with(receiver, filter_name, filter_method_name) }

        context "proc" do
          let(:filter_method_name) { Proc.new { :bar } }
          it { expect(receiver).to have_received(:define_singleton_method).once }
          it { expect(receiver.send('registered_filter_foo')).to eq(:bar) }
          it { expect(ActiveFacet::Filter).to have_received(:register).with(receiver, filter_name, "registered_filter_foo") }
        end
      end
    end

    describe "apply_facet_filters" do
      subject { [
        scope.apply_facet_filters(filter_values).to_sql,
        other_scope.apply_facet_filters(filter_values).to_sql
      ] }
      let(:scope) { receiver }
      let(:other_scope) { other_receiver }
      let(:resource_manager) { ActiveFacet::Helper }
      let(:filter_values) { { } }
      let(:receiver) { Class.new(ResourceA) {
        def self.name; 'Receiver'; end
        default_scope where('id DESC')

        scope :foo_bar, where(custom_attr: :foo)
        scope :filtered, where(custom_attr: :filtered)
        scope :filtered2, where(explicit_attr: :filtered2)
        scope :filtered_shared, where(internal_attr: :filtered_shared)

        facet_filter(:foo) { |f_value = nil| f_value ? filtered : scoped }
        facet_filter(:bar) { |f_value = nil| f_value ? filtered2 : scoped }
        facet_filter(:shared) { |f_value = nil| f_value ? filtered_shared : scoped }
      } }
      let(:other_receiver) { Class.new(ResourceA) {
        def self.name; 'OtherReceiver'; end
        default_scope where('id DESC')

        scope :filtered_others, where(custom_attr: :filtered_others)
        scope :filtered_shared, where(internal_attr: :filtered_shared)

        facet_filter(:others) { |f_value = nil| f_value ? filtered_others : scoped }
        facet_filter(:shared) { |f_value = nil| f_value ? filtered_shared : scoped }
      } }
      before do
        other_scope
        subject
      end

      context "default scope" do
        it { expect(subject).to eq([receiver.scoped.to_sql, other_receiver.scoped.to_sql]) }
      end

      context "unscoped" do
        let(:scope) { receiver.unscoped }
        let(:other_scope) { other_receiver.unscoped }
        it { expect(subject).to eq([receiver.unscoped.to_sql, other_receiver.unscoped.to_sql]) }
      end

      context "scoped" do
        let(:scope) { receiver.foo_bar }
        it { expect(subject).to eq([receiver.foo_bar.to_sql, other_receiver.scoped.to_sql]) }
      end

      context "matching filter" do
        let(:filter_values) { { foo: true} }
        it { expect(subject).to eq([receiver.filtered.to_sql, other_receiver.scoped.to_sql]) }
      end

      context "matching filters" do
        let(:filter_values) { { foo: true, bar: true} }
        it { expect(subject).to eq([receiver.filtered.filtered2.to_sql, other_receiver.scoped.to_sql]) }
      end

      context "matching shared filter" do
        let(:filter_values) { { shared: true} }
        it { expect(subject).to eq([receiver.filtered_shared.to_sql, other_receiver.filtered_shared.to_sql]) }
      end

      context "matching partial shared filter" do
        let(:filter_values) { { shared_receivers: true} }
        it { expect(subject).to eq([receiver.filtered_shared.to_sql, other_receiver.scoped.to_sql]) }
      end
    end

    describe "from_json" do
      subject { receiver.from_json(attributes, options) }
      let(:instance) { receiver.new }
      let(:attributes) { { foo: :bar } }
      let(:options) { {} }
      before do
        instance
        allow(receiver).to receive(:new) { instance }
        allow(instance).to receive(:from_json).and_call_original
        subject
      end

      it { expect(receiver).to have_received(:new).once }
      it { expect(instance).to have_received(:from_json).with(attributes, options).once }
    end
  end


  # Instance Methods

  describe "from_json" do
    subject { instance.from_json(attributes, options) }
    let(:instance) { receiver.new }
    let(:attributes) { { foo: :bar } }
    let(:options) { {} }
    before do
      allow(serializer).to receive(:from_hash).and_call_original
      allow(serializer2).to receive(:from_hash).and_call_original
      subject
    end
    it { expect(serializer).to have_received(:from_hash).with(instance, attributes) }
    it { expect(serializer2).to_not have_received(:from_hash) }

    context "options" do
      let(:options) { make_options version: 2 }
      it { expect(serializer).to_not have_received(:from_hash) }
      it { expect(serializer2).to have_received(:from_hash).with(instance, attributes) }
    end
  end

  describe "to_json" do
    subject { instance.as_json(options) }
    let(:instance) { create :resource_a, :with_master, :with_children }
    let(:options) { {} }
    let(:resource_manager) { ActiveFacet::Helper }

    before do
      allow(resource_manager).to receive(:serializer_for).and_call_original
      allow(serializer).to receive(:as_json).and_call_original
      subject
    end

    context "default" do
      it { expect(resource_manager).to_not have_received(:serializer_for) }
      it { expect(serializer).to_not have_received(:as_json) }
      it { expect(subject).to be_a Hash }
    end

    context "override" do
      let(:options) { make_options fields: :all }
      it { expect(resource_manager).to have_received(:serializer_for).exactly(5).times }
      it { expect(serializer).to have_received(:as_json).exactly(4).times }
      it { expect(subject).to be_a Hash }
    end
  end
end