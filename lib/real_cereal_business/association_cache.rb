# Encapsulate singleton cache behaviors
module RealCerealBusiness
  class AssociationCache
    cattr_accessor :caches
    attr_reader :cached_collection, :serializer, :cached_record_collections

    # Caches an set of records for use in nested association preloads identified by id
    # @param collection [Array] of ActiveRecord
    # @return [Hash]
    def cached_collection=(collection)
      self.class.push self
      @cached_collection = indexed_collection(collection, @cached_collection || {})
    end

    # Ensures that caches built during block are destroyed after
    # @param collection [Array] of ActiveRecord
    # @return [Hash]
    def perform(collection)
      #TODO --jdc this short circuits this entire feature set, is there any point to using it, or time to sunset?
      ::RealCerealBusiness.preload_associations ? perform!(collection) { yield } : yield
    end

    # Preload assocation for all records in cached collection
    # @param key [String] unique cache key identifying association & scopes
    # @param resource [ActiveRecord]
    # @param serializer [Serializer::Base]
    # @param relation [ActiveRelation] relation to query
    # @param association [ActiveRelation] relation to query
    # @return [Array] of ActiveRecord
    def preload_association_collection(key, resource, serializer, relation, association)
      ids = (cached_collection.try(:keys) || []).compact
      collections = cached_record_collections[resource.id]

      unless collections.key?(key) || ids.count <= 0 #TODO this is a bug, fix
        initialize_cached_record_links(key, relation)

        case relation
          when ActiveRecord::Reflection::ThroughReflection

            through = relation.through_reflection
            foreign_key = through.foreign_key
            stitch_key = relation.source_reflection.foreign_key
            stitchers_table_name = through.klass.table_name

            preload_through_association(key, stitchers_table_name, serializer, association, foreign_key, stitch_key, ids)

          when ActiveRecord::Reflection::AssociationReflection

            foreign_key = relation.foreign_key.to_sym

            if relation.belongs_to?
              preload_belongs_to_association(key, serializer, association, foreign_key)
            elsif relation.macro == :has_and_belongs_to_many
              stitch_key = relation.association_foreign_key
              stitchers_table_name = relation.options[:join_table]

              preload_through_association(key, stitchers_table_name, serializer, association, foreign_key, stitch_key, ids)
            else
              preload_has_x_association(key, serializer, association, foreign_key, ids)
            end
        end
      end

      collections[key]
    end

    private

    # @return [AssociationCache]
    def initialize(serializer)
      @serializer = serializer
      @cached_record_collections = Hash.new({})
    end

    # Ensures that caches built during block are destroyed after
    # @param collection [Array] of ActiveRecord
    # @return [Hash]
    def perform!(collection)
      self.cached_collection = collection
      self.class.adjust_cache_depth(1)
      yield
    ensure
      self.class.adjust_cache_depth(-1)
    end

    # Preload assocation for all records in cached has_and_belongs_to_many/through relations
    # @param key [String] unique cache key identifying association & scopes
    # @param stitchers_table_name [String] join table name
    # @param serializer [Serializer:Base]
    # @param association [ActiveRelation] relation to query
    # @param foreign_key [Symbol] attribute on join to use for linking
    # @param stitch_key [Symbol] attribute on join to use for linking
    # @param ids [Array] of int
    def preload_through_association(key, stitchers_table_name, serializer, association, foreign_key, stitch_key, ids)

      # TODO --jdc optomize this section to use a join instead of two queries.
      # the hard part is that the join table has multiple records for each target record, which
      # need to be captured in some sort of collection that can be itterated for linking

      stitchers = ActiveRecord::Base.connection.execute(<<-SQL
          SELECT #{stitch_key}, #{foreign_key}
          FROM #{stitchers_table_name}
          WHERE #{foreign_key} IN (#{ids.join(',')})
        SQL
      ).to_a.inject({}) do |result, stitcher|
        result[stitcher[0]] ||= []
        result[stitcher[0]] << stitcher[1]
        result
      end

      association = association.where(id: stitchers.keys)

      serializer.association_cache.cached_collection = association if serializer.present?

      association.each do |record|
        (stitchers[record.id] || []).each do |parent_id|
          parent = cached_collection[parent_id]
          link_cached_record(parent, key, record)
        end
      end
    end

    # Preload assocation for all records in cached belongs_to relations
    # @param key [String] unique cache key identifying association & scopes
    # @param serializer [Serializer:Base] of the type serialized by assocation
    # @param association [ActiveRelation] relation to query
    # @param foreign_key [Symbol] attribute on self to use for linking
    def preload_belongs_to_association(key, serializer, association, foreign_key)
      ids = cached_collection.map{ |id, record| record.send(foreign_key) }.compact
      association = association.where(:id => ids)

      if serializer.present?
        serializer.association_cache.cached_collection = association
        association = serializer.cached_collection
      else
        association = indexed_collection(association)
      end

      cached_collection.each_value do |parent|
        record = association[parent.send(foreign_key)]
        link_cached_record(parent, key, record)
      end
    end

    # Preload assocation for all records in cached has_* relations
    # @param key [String] unique cache key identifying association & scopes
    # @param serializer [Serializer:Base] of the type serialized by assocation
    # @param association [ActiveRelation] relation to query
    # @param foreign_key [Symbol] attribute on child to use for linking
    # @param ids [Array] integers ids of parent cache to query against
    def preload_has_x_association(key, serializer, association, foreign_key, ids)
      association = association.where(foreign_key => ids)
      serializer.association_cache.cached_collection = association if serializer.present?

      association.each do |record|
        parent = cached_collection[record.send(foreign_key)]
        link_cached_record(parent, key, record)
      end
    end

    # Empties cache of records built up during a recursive execution
    def reset_cached_collection
      @cached_collection = {}
    end

    # Indexes an array of ActiveRecords by their ids
    # @param collection [Array] ActiveRecord
    # @param index [Hash] ActiveRecord index to append to
    # @return [Hash]
    def indexed_collection(collection, index = {})
      collection.inject(index) do |result, x|
        result[x.id] = x
        result
      end
    end

    # Identifies a record as belonging to a preloaded association
    # @param resource [ActiveRecord] of the type serialized by self
    # @param key [String] unique cache key identifying association & scopes
    # @param record [ActiveRecord] of the type of the assocation
    # @return [Array] of ActiveRecord
    def link_cached_record(resource, key, record)
      return unless resource.present? && record.present?
      cached_record_collections[resource][key][:collection] << record
    end

    # Initialize association for all records in cache
    # Empty associations indicate that the record was visited and there is nothing left to fetch
    # @param key [String] unique cache key identifying association & scopes
    # @param relation [AssociationReflection]
    def initialize_cached_record_links(key, relation)
      cached_collection.each_value do |parent|
        cached_record_collections[parent.id][key] = {
          relation: relation,
          collection: []
        }
      end
    end
  end

  private

  # Registers cache as possessing a cache so it can be destroyed later
  # @param cache [Serializer:Base] attribute to get
  # @return [Array] of Serializer:Base
  def self.push(cache)
    self.caches ||= []
    caches << cache
  end

  # Modifies call stack depth, and clears cache at zero depth
  # @param increment [Integer] value to increments/decrement depth by
  def self.adjust_cache_depth(increment)
    @cache_depth ||= 0
    @cache_depth = @cache_depth + increment
    reset_caches if @cache_depth <= 0
  end

  # Destroyes caches
  def self.reset_caches
    if caches.is_a? Array
      caches.each do |cache|
        cache.send :reset_cached_collection
      end
    end
    self.caches = []
  end
end