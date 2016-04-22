require 'spec_helper'

describe ActiveFacet::ResourceInflector do

  let(:resource_serializer_class) { V1::ResourceA::ResourceASerializer }
  let(:association_serializer_class) { V1::ResourceB::ResourceBSerializer }
  let(:attribute_serializer_class) { V1::CustomizerAttributeSerializer }
  let(:instance) { Class.new {
    include ActiveFacet::ResourceInflector
    def resource_class
      ResourceA
    end
    def resource_attribute_name(field)
      field
    end
  }.new }

  describe ".get_association_reflection" do
    subject { instance.get_association_reflection(field) }

    context "relation" do
      let(:field) { :parent }
      it { expect(subject.class).to be(ActiveRecord::Reflection::AssociationReflection) }
    end

    context "field" do
      let(:field) { :explicit_attr }
      it { expect(subject).to be nil }
    end
  end

  describe ".get_association_serializer_class" do
    let(:options) { }
    subject { instance.get_association_serializer_class(field, options) }
    context "self association" do
      let(:field) { :parent }
      it { expect(subject).to be(resource_serializer_class.instance) }
    end

    context "association" do
      let(:field) { :master }
      it { expect(subject).to be(association_serializer_class.instance) }
    end

    context "attribute" do
      let(:field) { :explicit_attr }
      it { expect(subject).to be nil }
    end

    skip "todo: test version impact in lookups"
  end

  describe ".get_custom_serializer_class" do
    let(:options) { }
    subject { instance.get_custom_serializer_class(field, options) }
    context "registered" do
      let(:field) { :customizer }
      it { expect(subject).to be(attribute_serializer_class) }
    end
    context "unregistered" do
      let(:field) { :unregistered }
      it { expect(subject).to be(nil) }
    end
  end

  describe ".is_association?" do
    subject { instance.is_association?(field) }
    context "registered" do
      let(:field) { :parent }
      it { expect(subject).to be true }
    end

    context "unregistered" do
      let(:field) { :extras }
      it { expect(subject).to be true }
    end

    context "attribute" do
      let(:field) { :explicit_attr }
      it { expect(subject).to be false }
    end
  end
end