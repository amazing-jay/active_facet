require 'spec_helper'

describe ActiveFacet::Errors::AttributeError do

  context 'exists' do
    subject { described_class.new }
    it { expect{subject}.not_to raise_error }
  end

  context 'acts like an exception' do
    subject { raise described_class.new('hello world') }
    it { expect{subject}.to raise_error(described_class, 'hello world') }
  end

end