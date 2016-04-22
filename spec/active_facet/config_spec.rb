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
      :normalized_facets,
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
    it { expect(subject.normalized_facets).to be nil }
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

  describe ".alias_facet" do
    before do
      instance.alias_facet(:a, :b)
    end
    it { expect(subject.send(:facets)).to eq({a: :b}.with_indifferent_access) }
  end

  describe ".compile!" do
    subject { instance.compile! }

    before do
      instance.alias_facet :test, [:a, {b: :c}, {d: :e}]
      instance.resource_class = resource_class
    end

    it { expect(subject.compiled).to be true }
    it { expect(subject.normalized_facets).to eq({"all"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}}, "test"=>{"fields"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}, "attributes"=>{"a"=>{}, "b"=>{"c"=>{}}, "d"=>{"e"=>{}}}}}) }
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

    describe ".facet_itterator" do
      subject {
        {}.tap { |results|
          instance.facet_itterator(facet) { |field, nested_facet|
            results[field] = nested_facet
          }
        }
      }

      context "uncompiled" do
        let(:facet) { :a }
        let(:prehook) { }
        it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError, ActiveFacet::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
      end

      context "dirty compiled" do
        let(:facet) { :a }
        let(:prehook) {
          instance.resource_class = resource_class
          instance.compile!
          instance.alias_facet(:bar, :bar )
        }
        it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError, ActiveFacet::Errors::ConfigurationError::COMPILED_ERROR_MSG)}
      end

      context "symbol" do
        let(:facet) { :a }
        it { expect(subject).to eq({:a=>{}, :basic=>{}}) }
      end

      context "array of symbols" do
        let(:facet) { [:a, :b, :c] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :basic=>{}}) }
      end

      context "array of arrays" do
        let(:facet) { [:a, [:b, :c]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :basic=>{}}) }
      end

      context "hash" do
        let(:facet) { {a: :b, c: :d} }
        it { expect(subject).to eq({:a=>:b, :c=>:d, :basic=>{}}) }
      end

      context "hash of nils" do
        let(:facet) { {a: nil, c: :d} }
        it { expect(subject).to eq({:a=>{}, :c=>:d, :basic=>{}}) }
      end

      context "mixed" do
        let(:facet) { [:a, [[:b, {c: nil, d: :e}]]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}, :basic=>{}}) }
      end

      context "nested facets" do
        let(:facet) { [:a, [[:b, {c: nil}, {d: :e}, {f: [{g: :h}, :i]}]]] }
        it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}, :f=>{:g=>{:h=>{}}, :i=>{}}, :basic=>{}}) }
      end

      context "duplicates" do
        let(:facet) { [:a, [[:a, {a: nil}, {a: :e}]]] }
        it { expect(subject).to eq({:a=>{:e=>{}}, :basic=>{}}) }
      end

      context "all" do
        let(:facet) { :all }
        it { expect(subject).to eq({:basic=>{}}) }
      end

      context "basic & minimal" do
        let(:prehook) {
          instance.alias_facet(:minimal, [:a, [[:b, {c: nil, d: :e}]]] )
          instance.alias_facet(:basic, [:A, [[:B, {C: nil, D: :E}]]] )
          instance.alias_facet(:foo, [:aa, [{bar: nil}]] )
          instance.alias_facet(:bar, [[:bb, {cc: nil, dd: :ee}]] )
          instance.alias_facet(:empty, [] )
          instance.alias_facet(:identity, :identity )
          instance.resource_class = resource_class
          instance.compile!
        }

        context "minimal" do
          context "symbol" do
            let(:facet) { :minimal }
            it { expect(subject).to eq({"a"=>{}, "b"=>{}, "c"=>{}, "d"=>{"e"=>{}}}) }
          end

          context "array" do
            let(:facet) { [:minimal] }
            it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>{:e=>{}}}) }
          end

          context "hash" do
            let(:facet) { {minimal: nil} }
            it { expect(subject).to eq({:a=>{}, :b=>{}, :c=>{}, :d=>:e}) }
          end

          context "mixed" do
            let(:facet) { [:a, :d, [:c, {minimal: nil}]] }
            it { expect(subject).to eq({:a=>{}, :d=>{:e=>{}}, :c=>{}, :b=>{}}) }
          end
        end

        context "aliased" do
          let(:facet) { nil }
          it { expect(subject).to eq({"A"=>{}, "B"=>{}, "C"=>{}, "D"=>{"E"=>{}}}) }
        end

        context "nested aliases" do
          let(:facet) { :foo }
          it { expect(subject).to eq({:aa=>{}, :bb=>{}, :cc=>{}, :dd=>{:ee=>{}}, :A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end

        context "empty" do
          let(:facet) { :empty }
          it { expect(subject).to eq({:A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end

        context "identity" do
          let(:facet) { :identity }
          it { expect(subject).to eq({:identity=>{}, :A=>{}, :B=>{}, :C=>{}, :D=>{:E=>{}}}) }
        end
      end
    end

    describe ".resource_attribute_name" do
      subject { instance.resource_attribute_name(field, direction) }
      before do
        instance.transforms_from[:explicit_accessor] = :explicit_accessor
        instance.transforms_from[:alias_attr] = :aliased_accessor?
        instance.transforms_to[:explicit_accessor] = :explicit_accessor
        instance.transforms_to[:alias_attr] = :aliased_accessor
      end

      context "from" do
        let(:direction) { :from }
        let(:field) { :explicit_accessor }
        it { expect(subject).to eq(:explicit_accessor) }

        context "transformed" do
          let(:field) { :alias_attr }
          it { expect(subject).to eq(:aliased_accessor?) }
        end

        context "implicit" do
          let(:field) { :implicit_attr }
          it { expect(subject).to eq(:implicit_attr) }
        end
      end

      context "to" do
        let(:direction) { :to }
        let(:field) { :explicit_accessor }
        it { expect(subject).to eq(:explicit_accessor) }

        context "transformed" do
          let(:field) { :alias_attr }
          it { expect(subject).to eq(:aliased_accessor) }
        end

        context "implicit" do
          let(:field) { :implicit_attr }
          it { expect(subject).to eq(:implicit_attr) }
        end
      end
    end

    describe "private methods" do

      describe "dealias_facet!" do
        subject { instance.send(:dealias_facet!, facet, facet_alias) }
        let(:facet_alias) { nil }

        let(:prehook) {
          instance.alias_facet(:a, :a)
          instance.alias_facet(:b, :b)
          instance.alias_facet(:c, [:a, :d])
          instance.alias_facet(:basic, [:c, :e])
          instance.alias_facet(:minimal, [:e, :f])
          instance.resource_class = resource_class
          instance.compile!
        }

        before do
          allow(instance).to receive(:normalize_facet).and_call_original
          instance.send(:dealias_facet!, facet, facet_alias)
          subject
        end

        let(:facet) { :unknown_attr }
        it { expect(instance).to have_received(:normalize_facet).once }
        it { expect(instance.normalized_facets.keys).to include(facet.to_s) }
        it { expect(subject).to eq({"fields"=>{"unknown_attr"=>nil}}) }

        context 'named' do
          let(:facet_alias) { :custom }
          let(:facet) { :unknown_attr }
          before do
            instance.send(:dealias_facet!, facet)
          end
          it { expect(instance).to have_received(:normalize_facet).twice }
          it { expect(instance.normalized_facets.keys).to include(facet.to_s, facet_alias.to_s) }
          it { expect(subject).to eq({"fields"=>{"unknown_attr"=>nil}}) }
        end

        context "basic" do
          let(:facet) { :basic }
          it { expect(subject).to eq({"fields"=>{"a"=>{}, "d"=>{}, "e"=>{}}, "attributes"=>{"a"=>{}, "d"=>{}, "e"=>{}}}) }
        end

        context "all" do
          let(:facet) { :all }
          it { expect(subject).to eq({"fields"=>{"a"=>{}, "b"=>{}, "d"=>{}, "e"=>{}, "f"=>{}}, "attributes"=>{"a"=>{}, "b"=>{}, "d"=>{}, "e"=>{}, "f"=>{}}}) }
        end

        context "composite" do
          let(:facet) { [:foo, { :e => nil }, :basic] }
          it { expect(subject).to eq({"fields"=>{"foo"=>{}, "e"=>{}, "a"=>{}, "d"=>{}}}) }
        end
      end

      describe "dealias_facet" do
        subject { instance.send(:dealias_facet, facet) }
        let(:prehook) {
          instance.alias_facet(:a, :a)
          instance.alias_facet(:b, :b)
          instance.alias_facet(:c, [:a, :d, :association_a, { association_b: :aliased } ])
          instance.alias_facet(:basic, [:c, :e])
          instance.alias_facet(:minimal, [:e, :f])
          instance.resource_class = resource_class
          instance.compile!
        }

        context "string" do
          let(:facet) { 'basic' }
          it { expect(subject).to eq([[:a, :d, :association_a, {"association_b"=>:aliased}], :e]) }
        end

        context "symbol" do
          let(:facet) { :basic }
          it { expect(subject).to eq([[:a, :d, :association_a, {"association_b"=>:aliased}], :e]) }
        end

        context "all" do
          let(:facet) { :all }
          it { expect(subject).to eq({:a=>{}, :b=>{}, :d=>{}, :association_a=>{}, "association_b"=>{"aliased"=>{}}, :e=>{}, :f=>{}}) }
        end

        context "all_attributes" do
          let(:facet) { 'all_attributes' }
          it { expect(subject).to eq([:a, :association_a, :association_b, :b, :d, :e, :f]) }
        end

        context "composite" do
          let(:facet) { [:foo, { :e => nil }, :basic] }
          it { expect(subject).to eq([:foo, {:e=>{}}, [[:a, :d, :association_a, {"association_b"=>:aliased}], :e]]) }
        end
      end

      describe "normalize_facet" do
        subject { instance.send(:normalize_facet, facet) }

        context "symbol" do
          let(:facet) { :foo }
          it { expect(subject).to eq({ foo: nil }) }
        end

        context "string" do
          let(:facet) { 'foo' }
          it { expect(subject).to eq({ foo: nil }) }
        end

        context "array" do
          let(:facet) { [:foo, :bar] }
          it { expect(subject).to eq({ foo: {}, bar: {} }) }
        end

        context "hash" do
          let(:facet) { { foo: :nested, bar: :whatnot } }
          it { expect(subject).to eq({ foo: :nested, bar: :whatnot }) }
        end

        context "composite" do
          let(:facet) { [:foo, { bar: :whatnot }] }
          it { expect(subject).to eq({ foo: {}, bar: {whatnot: {} }}) }
        end
      end

      describe "default_facet" do
        subject { instance.send(:default_facet, facet) }

        context "nil" do
          let(:facet) { nil }
          it { expect(subject).to eq(:basic) }
        end

        context "symbol" do
          let(:facet) { :foo }
          it { expect(subject).to eq([:foo, :basic]) }

          context "basic" do
            let(:facet) { :basic }
            it { expect(subject).to eq([:basic]) }
          end

          context "minimal" do
            let(:facet) { :minimal }
            it { expect(subject).to eq(:minimal) }
          end
        end

        context "string" do
          let(:facet) { 'foo' }
          it { expect(subject).to eq([:foo, :basic]) }

          context "basic" do
            let(:facet) { 'basic' }
            it { expect(subject).to eq([:basic]) }
          end

          context "minimal" do
            let(:facet) { 'minimal' }
            it { expect(subject).to eq(:minimal) }
          end
        end

        context "array" do
          let(:facet) { ['foo', :bar, { alpha: :centuri }] }
          it { expect(subject).to eq(['foo', :bar, { alpha: :centuri }, :basic]) }

          context "basic" do
            let(:facet) { ['foo', :basic, :bar, { alpha: :centuri }] }
            it { expect(subject).to eq(['foo', :basic, :bar, { alpha: :centuri }]) }
          end

          context "embedded basic" do
            let(:facet) { ['foo', :bar, { alpha: :centuri, basic: nil }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:centuri, :basic=>nil}, :basic]) }
          end

          context "nested basic" do
            let(:facet) { ['foo', :bar, { alpha: :basic }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:basic}, :basic]) }
          end

          context "minimal" do
            let(:facet) { ['foo', :minimal, :bar, { alpha: :centuri }] }
            it { expect(subject).to eq(['foo', :minimal, :bar, { alpha: :centuri }]) }
          end

          context "embedded minimal" do
            let(:facet) { ['foo', :bar, { alpha: :centuri, minimal: nil }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:centuri, :minimal=>nil}]) }
          end

          context "nested minimal" do
            let(:facet) { ['foo', :bar, { alpha: :minimal }] }
            it { expect(subject).to eq(["foo", :bar, {:alpha=>:minimal}, :basic]) }
          end
        end

        context "hash" do
          let(:facet) { { alpha: :centuri } }
          it { expect(subject).to eq({ alpha: :centuri, basic: nil}) }

          context "basic" do
            let(:facet) { { alpha: :centuri, basic: nil } }
            it { expect(subject).to eq({:alpha=>:centuri, :basic=>nil}) }
          end

          context "nested basic" do
            let(:facet) { { alpha: :basic } }
            it { expect(subject).to eq({:alpha=>:basic, basic: nil}) }
          end

          context "minimal" do
            let(:facet) { { alpha: :centuri, minimal: nil } }
            it { expect(subject).to eq({:alpha=>:centuri, :minimal=>nil}) }
          end

          context "nested minimal" do
            let(:facet) { { alpha: :minimal } }
            it { expect(subject).to eq({:alpha=>:minimal, basic: nil}) }
          end
        end

        context "other" do
          let(:facet) { Object.new }
          let(:prehook) { }
          it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG, ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG)}
        end
      end

      describe "detect_facet" do
        subject { !!instance.send(:detect_facet, facet, key) }
        let(:key) { :key }

        context 'object' do
          let(:facet) { Object.new }
          let(:prehook) { }
          it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG, ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG)}
        end

        context "nil" do
          let(:facet) { nil }
          it { expect(subject).to eq(false) }
        end

        context "symbol" do
          let(:facet) { :symbol }
          it { expect(subject).to eq(false) }
        end

        context "key" do
          let(:facet) { :key }
          it { expect(subject).to eq(true) }
        end

        context "string" do
          let(:facet) { 'string' }
          it { expect(subject).to eq(false) }
        end

        context "key string" do
          let(:facet) { 'key' }
          it { expect(subject).to eq(true) }
        end

        context "array" do
          let(:facet) { [:foo, :bar] }
          it { expect(subject).to eq(false) }
        end

        context "key array" do
          let(:facet) { [:foo, :key, :bar] }
          it { expect(subject).to eq(true) }
        end

        context "hash" do
          let(:facet) { {foo: :bar} }
          it { expect(subject).to eq(false) }
        end

        context "key hash" do
          let(:facet) { {key: :bar} }
          it { expect(subject).to eq(true) }
        end

        context "composite" do
          let(:facet) { [:foo, :bar, [{alpha: :centuri}]] }
          it { expect(subject).to eq(false) }
        end

        context "key composite" do
          let(:facet) { [:foo, :bar, [{alpha: :centuri, key: :bar}]] }
          it { expect(subject).to eq(true) }
        end
      end

      describe "internal_facet_itterator" do
        subject {
          results = {}
          instance.send(:internal_facet_itterator, facet, lambda{ |field, nested_facet|
            results[nested_facet] = field
          })
          results
        }

        let(:facet) { { foo: :bar } }
        it { expect(subject).to eq({ bar: :foo }) }
      end

      describe "inject_facet" do
        subject { instance.send(:inject_facet, facet, key) }
        let(:facet) { { foo: :bar } }

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

      describe "aliased_facet?" do
        subject { instance.send(:aliased_facet?, facet) }
        let(:prehook) {
          instance.alias_facet(:a, :a)
          instance.alias_facet(:b, :a)
          instance.alias_facet(:c, [:a, :d, :association_a, { association_b: :aliased } ])
          instance.resource_class = resource_class
          instance.compile!
        }

        context 'not found' do
          let(:facet) { :foo }
          it { expect(subject).to eq(false) }
        end

        context 'identity' do
          let(:facet) { :a }
          it { expect(subject).to eq(false) }
        end

        context 'found' do
          let(:facet) { :b }
          it { expect(subject).to eq(true) }
        end

        context 'compiled' do
          let(:facet) { :all }
          it { expect(subject).to eq(false) }
        end

        context 'invalid' do
          let(:facet) { Object.new }
          it { expect(subject).to eq(false) }
        end
      end

      describe "merge_facets" do
        subject { instance.send(:merge_facets, a, b) }
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