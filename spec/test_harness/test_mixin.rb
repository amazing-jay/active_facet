module TestHarness
  module TestMixin
    extend ActiveSupport::Concern

    included do
      attr_accessor :explicit_attr,
        :implicit_attr,
        :custom_attr,
        :nested_accessor,
        :dynamic_accessor,
        :private_accessor,
        :aliased_accessor,
        :from_accessor,
        :to_accessor,
        :compound_accessor,
        :nested_compound_accessor,
        :unexposed_attr

      belongs_to :parent, class_name: 'TestHarness::TestResourceA'
      has_one :child, class_name: 'TestHarness::TestResourceA'

      belongs_to :owner, class_name: 'TestHarness::TestResourceB'
      has_many :delegates, class_name: 'TestHarness::TestResourceB'
      has_many :others, class_name: 'TestHarness::TestResourceB'
      has_many :extras, class_name: 'TestHarness::TestResourceB'
    end

    def method_missing(method_sym, *arguments, &block)
      if method_sym == :dynamic_attr
        return dynamic_accessor
      elsif method_sym == :dynamic_attr=
        self.dynamic_accessor = arguments[0]
      end
    end

    private

    def private_attr
      private_accessor
    end

    def private_attr=(value)
      self.private_accessor = value
    end
  end
end