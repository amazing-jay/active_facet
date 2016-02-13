class ResourceA < ActiveRecord::Base
  include ::ModelMixin

  belongs_to :parent, class_name: '::ResourceA'
  belongs_to :master, class_name: '::ResourceB'
  belongs_to :leader, class_name: '::ResourceB'

  has_many :children, class_name: '::ResourceA', foreign_key: 'parent_id'
  has_many :others, class_name: '::ResourceB', foreign_key: 'other_id'
  has_many :extras, class_name: '::ResourceB', foreign_key: 'extra_id'
end
