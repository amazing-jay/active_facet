module TestHarness
  class TestResourceB < ActiveRecord::Base
    include TestHarness::TestMixin
  end
end