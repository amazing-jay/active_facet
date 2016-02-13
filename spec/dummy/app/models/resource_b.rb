class ResourceB < ActiveRecord::Base
  include ModelMixin

  has_one :slave, class_name: '::ResourceA', foreign_key: 'master_id'
  has_many :delegates, class_name: '::ResourceA', foreign_key: 'leader_id'

  belongs_to :other, class_name: '::ResourceA'
  belongs_to :extra, class_name: '::ResourceA'
end
