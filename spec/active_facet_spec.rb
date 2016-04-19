require 'spec_helper'

describe ActiveFacet do

  it 'has a version number' do
    expect(ActiveFacet::VERSION).not_to be nil
  end

  describe ".deep_copy(o)" do
    let(:obj) { { a: [:b,:c], d: { e: :f } } }
    subject { described_class.deep_copy(obj) }
    before do
      subject[:d][:e] = :g
    end
    it { expect(obj).to eq({ a: [:b,:c], d: { e: :f } }) }
    it { expect(subject).to eq({ a: [:b,:c], d: { e: :g } }) }
  end

  skip 'class to be implemented'

end