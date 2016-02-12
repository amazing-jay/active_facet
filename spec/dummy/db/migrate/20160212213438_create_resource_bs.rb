class CreateResourceBs < ActiveRecord::Migration
  def change
    create_table :resource_bs do |t|
      t.timestamps null: false

      t.string :explicit_attr
      t.string :implicit_attr
      t.string :custom_attr
      t.string :nested_accessor
      t.string :dynamic_accessor
      t.string :private_accessor
      t.string :aliased_accessor
      t.string :from_accessor
      t.string :to_accessor
      t.string :compound_accessor
      t.string :nested_compound_accessor
      t.string :unexposed_attr
    end
  end
end
