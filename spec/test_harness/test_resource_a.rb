module TestHarness
  class TestResourceA < ActiveRecord::Base
    include TestHarness::TestMixin
  end
end