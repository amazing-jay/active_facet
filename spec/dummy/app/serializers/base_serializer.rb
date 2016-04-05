module BaseSerializer
  extend ActiveSupport::Concern

  included do
    transform :explicit_attr, as: :explicit_attr
    transform :alias_attr, as: :aliased_accessor
    transform :from_attr, from: :from_accessor
    transform :to_attr, to: :to_accessor
    transform :nested_attr, within: :nested_accessor
    transform :custom_attr, with: :customizer
    transform :compound_attr, with: :customizer, as: :compound_accessor
    transform :nested_compound_attr, with: :customizer, as: :compound_accessor, within: :nested_compound_accessor
    extension :extension_attr

    expose :attrs, as: [:explicit_attr, :implicit_attr, :dynamic_attr, :private_attr, :alias_attr, :to_attr, :from_attr]
    expose :nested, as: [:nested_attr, :nested_compound_attr]
    expose :custom, as: [:custom_attr, :compound_attr, :nested_compound_attr]
    expose :minimal, as: [:explicit_attr]
    expose :basic, as: [:minimal, :nested_attr]
    expose :relations, as: [:parent, :master, :leader, :master, :children, :others, :extras]
    expose :alias_relation, as: [:others]
    expose :deep_relations, as: [
      {parent: {children: :attr}},
      {children: :nested},
      :master,
      {extras: :minimal},
      {alias_relation: :implicit_attr}
    ]

  end
end