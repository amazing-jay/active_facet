FactoryGirl.define do
  factory :resource_b do

    explicit_attr { 'explicit_attr' }
    implicit_attr { 'implicit_attr' }
    custom_attr { 'custom_attr' }
    nested_accessor { { nested_attr: 'nested_attr'} }
    dynamic_accessor { 'dynamic_accessor' }
    private_accessor { 'private_accessor' }
    aliased_accessor { 'aliased_accessor' }
    from_accessor { 'from_accessor' }
    to_accessor { 'to_accessor' }
    compound_accessor { 'compound_accessor' }
    nested_compound_accessor { 'nested_compound_accessor' }
    unexposed_attr { 'unexposed_attr' }

    trait :with_slave do
      slave { FactoryGirl.create :resource_a }
    end

    trait :with_other do
      other { FactoryGirl.create :resource_a }
    end

    trait :with_extra do
      extra { FactoryGirl.create :resource_a }
    end

    trait :with_delegates do
      delegates { create_list(:resource_a, 3) }
    end
  end
end
