require 'spec_helper'

describe ActiveFacet::ActsAsActiveFacet do
  let(:serializer) { V1::ResourceA::ResourceASerializer.new }
  let(:serializer2) { V2::ResourceA::ResourceASerializer.new }
  let(:receiver) { ResourceA }
  let(:method_aliases) { {
      includes_method_name:       :includes_method_name,
      apply_includes_method_name: :apply_includes_method_name,
      filter_method_name:         :filter_method_name,
      apply_filters_method_name:  :apply_filters_method_name,
      unserialize_method_name:    :unserialize_method_name,
      serialize_method_name:      :serialize_method_name
    } }

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
    before do
      receiver.acts_as_active_facet
    end

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

      #     # Applies all filters registered with this resource on a ProxyCollection
      #     # @param filter_values [Hash] keys = registerd filter name, values = filter arguments
      #     # TODO:: change scoped to self(or similar) to preserve the current relation
      #     define_method(acts_as_active_facet_options[:apply_filters_method_name]) do |filter_values = nil|
      #       filter_values = (filter_values || {}).with_indifferent_access
      #       ActiveFacet::Filter.registered_filters_for(self).inject(scoped) do |result, (k,v)|
      #         filter = ActiveFacet::ResourceManager.instance.resource_map(self).detect { |map_entry|
      #           filter_values.keys.include? "#{k}_#{map_entry}"
      #         }
      #         args = filter_values["#{k}_#{filter}"] || filter_values[k]
      #         result.send(v, *args) || result
      #       end
      #     end

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
      #   # Serializes a resource using facets
      #   # Falls back to default behavior when RCB key is not present
      #   # @param options [Hash]
      #   # @return [Hash]
      #   define_method(acts_as_active_facet_options[:serialize_method_name]) do |options = nil|
      #     if options.present? && options.key?(ActiveFacet.opts_key) &&
      #         (serializer = ActiveFacet::ResourceManager.instance.serializer_for(self.class, options)).present?
      #       serializer.as_json(self, options)
      #     else
      #       super(options)
      #     end
      #   end
      # end

end