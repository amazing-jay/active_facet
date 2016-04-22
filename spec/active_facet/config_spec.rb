require 'spec_helper'

describe ActiveFacet::Config do
  subject { instance }
  before do
    prehook
  end

  let(:prehook) { }
  let(:instance) { described_class.new }
  let(:resource_class) { ResourceA }
  let(:attrs) { [
    :transforms_from,
    :transforms_to,
    :serializers,
    :namespaces,
    :extensions
  ] }

  describe "public attributes" do
    it { expect(described_class.instance_methods).to include(
      :resource_class,
      :normalized_field_sets,
      :transforms_from,
      :transforms_to,
      :serializers,
      :namespaces,
      :extensions
    )}
  end

  describe ".initialize" do
    it { expect(subject.compiled).to              be false }
    it { expect(subject.resource_class).to        be nil }
    it { expect(subject.normalized_field_sets).to be nil }
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
    subject { instance.compile! }

    before do
      instance.alias_field_set :test, [:a, {b: :c}, {d: :e}]
      instance.resource_class = resource_class
    end

    it { expect(subject.compiled).to be true }
    it { expect(subject.normalized_field_sets).to eq({"all"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}}, "test"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}}}) }
  end

  describe ".merge!" do
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

  describe "post compile methods" do
    let(:prehook) {
      instance.resource_class = resource_class
      instance.compile!
    }

    describe ".field_set_itterator" do
      subject {
        {}.tap { |results|
          instance.field_set_itterator(field_set) { |field, nested_field_set|
            results[field] = nested_field_set
          }
        }
      }

      context "uncompiled" do
        let(:field_set) { :a }
        let(:prehook) { }
        it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError, ActiveFacet::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
      end

      context "dirty compiled" do
        let(:field_set) { :a }
        let(:prehook) {
          instance.resource_class = resource_class
          instance.compile!
          instance.alias_field_set(:bar, :bar )
        }
        it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError, ActiveFacet::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
      end

      context "symbol" do
        let(:field_set) { :a }
        it { expect(subject).to eq({:a=>{}, :basic=>{}}) }
      end

      context "array of symbols" do
        let(:field_set) { [:a, :b, :c] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :basic=>{}}) }
      end

      context "array of arrays" do
        let(:field_set) { [:a, [:b, :c]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :basic=>{}}) }
      end

      context "hash" do
        let(:field_set) { {a: :b, c: :d} }
        it { expect(subject).to eq({:a=>:b, :c=>:d, :basic=>{}}) }
      end

      context "hash of nils" do
        let(:field_set) { {a: nil, c: :d} }
        it { expect(subject).to eq({:a=>{}, :c=>:d, :basic=>{}}) }
      end

      context "mixed" do
        let(:field_set) { [:a, [[:b, {c: nil, d: :e}]]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}, :basic=>{}}) }
      end

      context "nested field_sets" do
        let(:field_set) { [:a, [[:b, {c: nil}, {d: :e}, {f: [{g: :h}, :i]}]]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}, :f=>{:g=>{:h=>{}}, :i=>{}}, :basic=>{}}) }
      end

      context "duplicates" do
        let(:field_set) { [:a, [[:a, {a: nil}, {a: :e}]]] }
        it { expect(subject).to eq({:a=>{:e=>{}}, :basic=>{}}) }
      end

      context "all" do
        let(:field_set) { :all }
        it { expect(subject).to eq({:basic=>{}}) }
      end

      context "basic & minimal" do
        let(:prehook) {
          instance.alias_field_set(:minimal, [:a, [[:b, {c: nil, d: :e}]]] )
          instance.alias_field_set(:basic, [:A, [[:B, {C: nil, D: :E}]]] )
          instance.alias_field_set(:foo, [:aa, [{bar: nil}]] )
          instance.alias_field_set(:bar, [[:bb, {cc: nil, dd: :ee}]] )
          instance.alias_field_set(:empty, [] )
          instance.alias_field_set(:identity, :identity )
          instance.resource_class = resource_class
          instance.compile!
        }

        context "minimal" do
          context "symbol" do
            let(:field_set) { :minimal }
            it { expect(subject).to eq({"a"=>{}, "b"=>{}, "c"=>{}, "d"=>{"e"=>{}}}) }
          end

          context "array" do
            let(:field_set) { [:minimal] }
            it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}}) }
          end

          context "hash" do
            let(:field_set) { {minimal: nil} }
            it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>:e}) }
          end

          context "mixed" do
            let(:field_set) { [:a, :d, [:c, {minimal: nil}]] }
            it { expect(subject).to eq({:a=>{}, :d=>{:e=>{}}, :c=>{}, :b=>{}}) }
          end
        end

        context "aliased" do
          let(:field_set) { nil }
          it { expect(subject).to eq({"A"=>{}, "B"=>{}, "C"=>{}, "D"=>{"E"=>{}}}) }
        end

        context "nested aliases" do
          let(:field_set) { :foo }
          it { expect(subject).to eq({:aa=>{}, :bb=>{}, :cc=>{}, :dd=>{:ee=>{}}, :A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end

        context "empty" do
          let(:field_set) { :empty }
          it { expect(subject).to eq({:A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end

        context "identity" do
          let(:field_set) { :identity }
          it { expect(subject).to eq({:identity=>{}, :A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end
      end
    end

    describe "private methods" do

      describe "dealias_field_set!" do
        subject { instance.send(:dealias_field_set!, field_set, field_set_alias) }
        let(:field_set_alias) { nil }

        let(:prehook) {
          instance.alias_field_set(:a, :a)
          instance.alias_field_set(:b, :b)
          instance.alias_field_set(:c, [:a, :d])
          instance.alias_field_set(:basic, [:c, :e])
          instance.alias_field_set(:minimal, [:e, :f])
          instance.resource_class = resource_class
          instance.compile!
        }

        before do
          allow(instance).to receive(:normalize_field_set).and_call_original
          instance.send(:dealias_field_set!, field_set, field_set_alias)
          subject
        end

        let(:field_set) { :unknown_attr }
        it { expect(instance).to have_received(:normalize_field_set).once }
        it { expect(instance.normalized_field_sets.keys).to include(field_set.to_s) }
        it { expect(subject).to eq({"fields"=>{"unknown_attr"=>nil}}) }

        context 'named' do
          let(:field_set_alias) { :custom }
          let(:field_set) { :unknown_attr }
          before do
            instance.send(:dealias_field_set!, field_set)
          end
          it { expect(instance).to have_received(:normalize_field_set).twice }
          it { expect(instance.normalized_field_sets.keys).to include(field_set.to_s, field_set_alias.to_s) }
          it { expect(subject).to eq({"fields"=>{"unknown_attr"=>nil}}) }
        end

        context "basic" do
          let(:field_set) { :basic }
          it { expect(subject).to eq({"fields"=>{"a"=>{}, "d"=>{}, "e"=>{}}, "attributes"=>{"a"=>{}, "d"=>{}, "e"=>{}}}) }
        end

        context "all" do
          let(:field_set) { :all }
          it { expect(subject).to eq({"fields"=>{"a"=>{}, "b"=>{}, "d"=>{}, "e"=>{}, "f"=>{}}, "attributes"=>{"a"=>{}, "b"=>{}, "d"=>{}, "e"=>{}, "f"=>{}}}) }
        end

        context "composite" do
          let(:field_set) { [:foo, { :e => nil }, :basic] }
          it { expect(subject).to eq({"fields"=>{"foo"=>{}, "e"=>{}, "a"=>{}, "d"=>{}}}) }
        end
      end

      describe "dealias_field_set" do
        subject { instance.send(:dealias_field_set, field_set) }
        let(:prehook) {
          instance.alias_field_set(:a, :a)
          instance.alias_field_set(:b, :b)
          instance.alias_field_set(:c, [:a, :d, :association_a, { association_b: :aliased } ])
          instance.alias_field_set(:basic, [:c, :e])
          instance.alias_field_set(:minimal, [:e, :f])
          instance.resource_class = resource_class
          instance.compile!
        }

        context "string" do
          let(:field_set) { 'basic' }
          it { expect(subject).to eq([[:a, :d, :association_a, {"association_b"=>:aliased}], :e]) }
        end

        context "symbol" do
          let(:field_set) { :basic }
          it { expect(subject).to eq([[:a, :d, :association_a, {"association_b"=>:aliased}], :e]) }
        end

        context "all" do
          let(:field_set) { :all }
          it { expect(subject).to eq({:a=>{}, :b=>{}, :d=>{}, :association_a=>{}, "association_b"=>{"aliased"=>{}}, :e=>{}, :f=>{}}) }
        end

        context "all_attributes" do
          let(:field_set) { 'all_attributes' }
          it { expect(subject).to eq([:a, :association_a, :association_b, :b, :d, :e, :f]) }
        end

        context "composite" do
          let(:field_set) { [:foo, { :e => nil }, :basic] }
          it { expect(subject).to eq([:foo, {:e=>{}}, [[:a, :d, :association_a, {"association_b"=>:aliased}], :e]]) }
        end
      end

      describe "normalize_field_set" do
        subject { instance.send(:normalize_field_set, field_set) }

        context "symbol" do
          let(:field_set) { :foo }
          it { expect(subject).to eq({ foo: nil }) }
        end

        context "string" do
          let(:field_set) { 'foo' }
          it { expect(subject).to eq({ foo: nil }) }
        end

        context "array" do
          let(:field_set) { [:foo, :bar] }
          it { expect(subject).to eq({ foo: {}, bar: {} }) }
        end

        context "hash" do
          let(:field_set) { { foo: :nested, bar: :whatnot } }
          it { expect(subject).to eq({ foo: :nested, bar: :whatnot }) }
        end

        context "composite" do
          let(:field_set) { [:foo, { bar: :whatnot }] }
          it { expect(subject).to eq({ foo: {}, bar: {whatnot: {} }}) }
        end
      end

      describe "default_field_set" do
        subject { instance.send(:default_field_set, field_set) }

        context "nil" do
          let(:field_set) { nil }
          it { expect(subject).to eq(:basic) }
        end

        context "symbol" do
          let(:field_set) { :foo }
          it { expect(subject).to eq([:foo, :basic]) }

          context "basic" do
            let(:field_set) { :basic }
            it { expect(subject).to eq([:basic]) }
          end

          context "minimal" do
            let(:field_set) { :minimal }
            it { expect(subject).to eq(:minimal) }
          end
        end

        context "string" do
          let(:field_set) { 'foo' }
          it { expect(subject).to eq([:foo, :basic]) }

          context "basic" do
            let(:field_set) { 'basic' }
            it { expect(subject).to eq([:basic]) }
          end

          context "minimal" do
            let(:field_set) { 'minimal' }
            it { expect(subject).to eq(:minimal) }
          end
        end

        context "array" do
          let(:field_set) { ['foo', :bar, { alpha: :centuri }] }
          it { expect(subject).to eq(['foo', :bar, { alpha: :centuri }, :basic]) }

          context "basic" do
            let(:field_set) { ['foo', :basic, :bar, { alpha: :centuri }] }
            it { expect(subject).to eq(['foo', :basic, :bar, { alpha: :centuri }]) }
          end

          context "embedded basic" do
            let(:field_set) { ['foo', :bar, { alpha: :centuri, basic: nil }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:centuri, :basic=>nil}, :basic]) }
          end

          context "nested basic" do
            let(:field_set) { ['foo', :bar, { alpha: :basic }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:basic}, :basic]) }
          end

          context "minimal" do
            let(:field_set) { ['foo', :minimal, :bar, { alpha: :centuri }] }
            it { expect(subject).to eq(['foo', :minimal, :bar, { alpha: :centuri }]) }
          end

          context "embedded minimal" do
            let(:field_set) { ['foo', :bar, { alpha: :centuri, minimal: nil }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:centuri, :minimal=>nil}]) }
          end

          context "nested minimal" do
            let(:field_set) { ['foo', :bar, { alpha: :minimal }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:minimal}, :basic]) }
          end
        end

        context "hash" do
          let(:field_set) { { alpha: :centuri } }
          it { expect(subject).to eq({ alpha: :centuri, basic: nil}) }

          context "basic" do
            let(:field_set) { { alpha: :centuri, basic: nil } }
            it { expect(subject).to eq({:alpha=>:centuri, :basic=>nil}) }
          end

          context "nested basic" do
            let(:field_set) { { alpha: :basic } }
            it { expect(subject).to eq({:alpha=>:basic, basic: nil}) }
          end

          context "minimal" do
            let(:field_set) { { alpha: :centuri, minimal: nil } }
            it { expect(subject).to eq({:alpha=>:centuri, :minimal=>nil}) }
          end

          context "nested minimal" do
            let(:field_set) { { alpha: :minimal } }
            it { expect(subject).to eq({:alpha=>:minimal, basic: nil}) }
          end
        end

        context "other" do
          let(:field_set) { Object.new }
          let(:prehook) { }
          it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError::FIELD_SET_ERROR_MSG, ActiveFacet::Errors::ConfigurationError::FIELD_SET_ERROR_MSG)}
        end
      end

      describe "detect_field_set" do
        subject { !!instance.send(:detect_field_set, field_set, key) }
        let(:key) { :key }

        context 'object' do
          let(:field_set) { Object.new }
          let(:prehook) { }
          it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError::FIELD_SET_ERROR_MSG, ActiveFacet::Errors::ConfigurationError::FIELD_SET_ERROR_MSG)}
        end

        context "nil" do
          let(:field_set) { nil }
          it { expect(subject).to eq(false) }
        end

        context "symbol" do
          let(:field_set) { :symbol }
          it { expect(subject).to eq(false) }
        end

        context "key" do
          let(:field_set) { :key }
          it { expect(subject).to eq(true) }
        end

        context "string" do
          let(:field_set) { 'string' }
          it { expect(subject).to eq(false) }
        end

        context "key string" do
          let(:field_set) { 'key' }
          it { expect(subject).to eq(true) }
        end

        context "array" do
          let(:field_set) { [:foo, :bar] }
          it { expect(subject).to eq(false) }
        end

        context "key array" do
          let(:field_set) { [:foo, :key, :bar] }
          it { expect(subject).to eq(true) }
        end

        context "hash" do
          let(:field_set) { {foo: :bar} }
          it { expect(subject).to eq(false) }
        end

        context "key hash" do
          let(:field_set) { {key: :bar} }
          it { expect(subject).to eq(true) }
        end

        context "composite" do
          let(:field_set) { [:foo, :bar, [{alpha: :centuri}]] }
          it { expect(subject).to eq(false) }
        end

        context "key composite" do
          let(:field_set) { [:foo, :bar, [{alpha: :centuri, key: :bar}]] }
          it { expect(subject).to eq(true) }
        end
      end

      describe "internal_field_set_itterator" do
        subject {
          results = {}
          instance.send(:internal_field_set_itterator, field_set, lambda{ |field, nested_field_set|
            results[nested_field_set] = field
          })
          results
        }

        let(:field_set) { { foo: :bar } }
        it { expect(subject).to eq({ bar: :foo }) }
      end

      describe "inject_field_set" do
        subject { instance.send(:inject_field_set, field_set, key) }
        let(:field_set) { { foo: :bar } }

        context 'symbol' do
          let(:key) { :key }
          it { expect(subject).to eq({ foo: :bar, key: {} }) }
        end

        context 'duplicate symbol' do
          let(:key) { :foo }
          it { expect(subject).to eq({ foo: {} }) }
        end

        context 'string' do
          let(:key) { 'key' }
          it { expect(subject).to eq({ foo: :bar, key: {} }) }
        end

        context 'duplicate string' do
          let(:key) { 'foo' }
          it { expect(subject).to eq({ foo: {} }) }
        end

        context 'hash' do
          let(:key) { { alpha: :centuri, foo: :buzz } }
          it { expect(subject).to eq({ foo: :buzz, alpha: :centuri }) }
        end

        context 'array' do
          let(:key) { [ :cobalt, { alpha: :centuri, foo: :buzz }] }
          it { expect(subject).to eq({:foo=>:buzz, :cobalt=>{}, :alpha=>:centuri}) }
        end
      end

      describe "aliased_field_set?" do
        subject { instance.send(:aliased_field_set?, field_set) }
        let(:prehook) {
          instance.alias_field_set(:a, :a)
          instance.alias_field_set(:b, :a)
          instance.alias_field_set(:c, [:a, :d, :association_a, { association_b: :aliased } ])
          instance.resource_class = resource_class
          instance.compile!
        }

        context 'not found' do
          let(:field_set) { :foo }
          it { expect(subject).to eq(false) }
        end

        context 'identity' do
          let(:field_set) { :a }
          it { expect(subject).to eq(false) }
        end

        context 'found' do
          let(:field_set) { :b }
          it { expect(subject).to eq(true) }
        end

        context 'compiled' do
          let(:field_set) { :all }
          it { expect(subject).to eq(false) }
        end

        context 'invalid' do
          let(:field_set) { Object.new }
          it { expect(subject).to eq(false) }
        end
      end

      describe "merge_field_sets" do
        subject { instance.send(:merge_field_sets, a, b) }
        let(:a) { { foo: :bar } }
        let(:b) { { alpha: :omega } }
        it { expect(subject).to eq({:foo=>:bar, :alpha=>{:omega=>{}}}) }

        context 'one level deep' do
          let(:a) { { a: { foo: :bar } } }
          let(:b) { { a: { alpha: :omega } } }
          it { expect(subject).to eq({:a=>{:foo=>:bar, :alpha=>{:omega=>{}}}}) }
        end

        context 'two levels deep' do
          let(:a) { { a: { b: { foo: :bar } } } }
          let(:b) { { a: { b: { alpha: :omega } } } }
          it { expect(subject).to eq({:a=>{:b=>{:foo=>:bar, :alpha=>{:omega=>{}}}}} ) }
        end
      end
    end
  end
end