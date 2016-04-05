module ModelMixin
  extend ActiveSupport::Concern

  included do
    serialize :nested_accessor, JSON
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
