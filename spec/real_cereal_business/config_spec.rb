require 'spec_helper'

describe RealCerealBusiness::Config do

  subject { instance }
  let(:instance) { described_class.new }
  let(:serializer) { double('serializer') }
  let(:attrs) { [
    :transforms_from,
    :transforms_to,
    :serializers,
    :namespaces,
    :extensions
  ] }

  before do
    allow(serializer).to receive(:is_association?) { |attribute| [:a, :b].include? attribute.to_sym }
    allow(serializer).to receive(:exposed_aliases) { |field_set_alias = :all, include_relations = false, include_nested_field_sets = false|
      {}
    }
  end

  describe "public attributes" do
    it { expect(described_class.instance_methods).to include(
      :serializer,
      :normalized_field_sets,
      :transforms_from,
      :transforms_to,
      :serializers,
      :namespaces,
      :extensions
    )}
  end

  describe ".initialize" do
    it { expect(subject.compiled).to              be_false }
    it { expect(subject.serializer).to            be_nil }
    it { expect(subject.normalized_field_sets).to be_nil }
    it { expect(subject.transforms_from).to       eq({}) }
    it { expect(subject.transforms_to).to         eq({}) }
    it { expect(subject.serializers).to           eq({}) }
    it { expect(subject.namespaces).to            eq({}) }
    it { expect(subject.extensions).to            eq({}) }
  end

  describe ".transforms" do
    before do
      instance.transforms_from[:a] = :b
      instance.transforms_to[:c] = :d
    end

    it { expect(subject.transforms).to eq({a: :b}.with_indifferent_access) }
    it { expect(subject.transforms(:from)).to eq({a: :b}.with_indifferent_access) }
    it { expect(subject.transforms(:to)).to eq({c: :d}.with_indifferent_access) }
  end

  describe ".alias_field_set" do
    before do
      instance.alias_field_set(:a, :b)
    end
    it { expect(subject.send(:field_sets)).to eq({a: :b}.with_indifferent_access) }
  end

  describe ".compile!" do
    subject { instance.compile!(serializer) }

    before do
      instance.alias_field_set :test, [:a, {b: :c}, {d: :e}]
    end

    it { expect(subject.compiled).to be_true }
    it { expect(subject.serializer).to eq(serializer) }
    it { expect(subject.normalized_field_sets).to eq({"all"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"d"=>{"e"=>{}}}}, "test"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"d"=>{"e"=>{}}}}}) }

  end

  describe ".merge! config" do

    before do
      other = described_class.new
      attrs.each do |attribute|
        instance.send(attribute)[:a] = :A
        other.send(attribute)[:b] = :B
        instance.send(attribute)[:c] = :C
        other.send(attribute)[:c] = attribute
      end
      instance.merge! other
    end

    it {
      attrs.each do |attribute|
        expect(subject.send(attribute)).to eq({a: :A, b: :B, c: attribute}.with_indifferent_access)
      end
    }
  end

  describe ".field_set_itterator" do
    subject {
      [[],{}].tap { |fields|
        instance.field_set_itterator(field_set) { |field, nested_field_set|
          fields[0] << field.to_sym
          fields[1][field] = nested_field_set unless nested_field_set.blank?
        }
        fields[0].sort!
      }
    }

    before do
      prehook
    end

    let(:prehook) { instance.compile!(serializer) }

    context "uncompiled" do
      let(:field_set) { :a }
      let(:prehook) { }
      it { expect{subject}.to raise_error(RealCerealBusiness::Errors::ConfigurationError, RealCerealBusiness::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
    end

    context "dirty compiled" do
      let(:field_set) { :a }
      let(:prehook) {
        instance.compile!(serializer)
        instance.alias_field_set(:bar, :bar )
      }
      it { expect{subject}.to raise_error(RealCerealBusiness::Errors::ConfigurationError, RealCerealBusiness::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
    end

    context "symbol" do
      let(:field_set) { :a }
      it { expect(subject[0]).to eq([:a, :basic]) }
    end

    context "array of symbols" do
      let(:field_set) { [:a, :b, :c] }
      it { expect(subject[0]).to eq([:a, :b, :basic, :c]) }
      it { expect(subject[1]).to be_blank }
    end

    context "array of arrays" do
      let(:field_set) { [:a, [:b, :c]] }
      it { expect(subject[0]).to eq([:a, :b, :basic, :c]) }
      it { expect(subject[1]).to be_blank }
    end

    context "hash" do
      let(:field_set) { {a: :b, c: :d} }
      it { expect(subject[0]).to eq([:a, :basic, :c]) }
      it { expect(subject[1]).to eq({a: :b, c: :d}) }
    end

    context "hash of nils" do
      let(:field_set) { {a: nil, c: :d} }
      it { expect(subject[0]).to eq([:a, :basic, :c]) }
      it { expect(subject[1]).to eq({c: :d}) }
    end

    context "mixed" do
      let(:field_set) { [:a, [[:b, {c: nil, d: :e}]]] }
      it { expect(subject[0]).to eq([:a, :b, :basic, :c, :d]) }
      it { expect(subject[1]).to eq({d: {e: {}}}) }
    end

    context "nested field_sets" do
      let(:field_set) { [:a, [[:b, {c: nil}, {d: :e}, {f: [{g: :h}, :i]}]]] }
      it { expect(subject[0]).to eq([:a, :b, :basic, :c, :d, :f]) }
      it { expect(subject[1]).to eq({:d=>{:e=>{}}, :f=>{:g=>{:h=>{}}, :i=>{}}}) }
    end

    context "duplicates" do
      let(:field_set) { [:a, [[:a, {a: nil}, {a: :e}]]] }
      it { expect(subject[0]).to eq([:a, :basic]) }
      it { expect(subject[1]).to eq({a: {e: {}}}) }
    end

    context "basic & minimal" do
      let(:prehook) {
        instance.alias_field_set(:minimal, [:a, [[:b, {c: nil, d: :e}]]] )
        instance.alias_field_set(:basic, [:A, [[:B, {C: nil, D: :E}]]] )
        instance.alias_field_set(:foo, [:aa, [{bar: nil}]] )
        instance.alias_field_set(:bar, [[:bb, {cc: nil, dd: :ee}]] )
        instance.alias_field_set(:empty, [] )
        instance.alias_field_set(:identity, :identity )
        instance.compile!(serializer)
      }

      context "minimal" do
        context "symbol" do
          let(:field_set) { :minimal }
          it { expect(subject[0]).to eq([:a, :b, :c, :d]) }
        end

        context "array" do
          let(:field_set) { [:minimal] }
          it { expect(subject[0]).to eq([:a, :b, :c, :d]) }
        end

        context "hash" do
          let(:field_set) { {minimal: nil} }
          it { expect(subject[0]).to eq([:a, :b, :c, :d]) }
        end

        context "mixed" do
          let(:field_set) { [:a, :d, [:c, {minimal: nil}]] }
          it { expect(subject[0]).to eq([:a, :b, :c, :d]) }
        end
      end

      context "aliased" do
        let(:field_set) { nil }
        it { expect(subject[0]).to eq([:A, :B, :C, :D]) }
      end

      context "nested aliases" do
        let(:field_set) { :foo }
        it { expect(subject[0]).to eq([:A, :B, :C, :D, :aa, :bb, :cc, :dd]) }
      end

      context "empty" do
        let(:field_set) { :empty }
        it { expect(subject[0]).to eq([:A, :B, :C, :D]) }
      end

      context "identity" do
        let(:field_set) { :identity }
        it { expect(subject[0]).to eq([:A, :B, :C, :D, :identity]) }
      end
    end

  end

end