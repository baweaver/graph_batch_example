# typed: strict

# This loader is a GraphQL-Ruby Dataloader source that intelligently preloads
# ActiveRecord associations using information from `lookahead` queries.
#
# This class batches requests for a given association and uses the lookahead structure
# to determine nested associations to preload—avoiding N+1 queries while keeping the
# preloading logic dynamic and context-sensitive.
#
# GraphQL Lookaheads:
# --------------------
#
# In GraphQL-Ruby, `lookahead` is an optimization feature that allows you to introspect
# the fields that will be selected in a query _before_ resolving the object. This allows
# the system to proactively determine which nested fields (associations) are needed,
# enabling you to preload them efficiently (e.g., via ActiveRecord `.includes` or `preload`).
#
module Loaders
  module BatchedPreloader
    MAX_BATCH_SIZE = 500

    def self.preload(records:, associations:)
      Rails.logger.debug(
        "[BatchedPreloader] Trying to preload #{records.size} records"
      )

      Rails.logger.debug(
        "[BatchedPreloader] Trying to load tree: #{JSON.pretty_generate(associations)}"
      )

      records.each_slice(MAX_BATCH_SIZE) do |batch|
        ActiveRecord::Associations::Preloader.new(
          records: batch,
          associations: associations
        ).call
      end
    end
  end

  class AssociationDataloaderWithLookahead < GraphQL::Dataloader::Source
    extend T::Sig

    sig do
      params(
        association_name: T.any(String, Symbol),
        context: T.untyped
      ).void
    end
    def initialize(association_name, context:)
      @association_name = association_name.to_sym
      @context = context

      @object_to_lookahead = T.let({}, T::Hash[ActiveRecord::Base, GraphQL::Execution::Lookahead])
      @already_preloaded = T.let(Set.new, T::Set[Integer])
    end

    # Called by field resolvers to register lookahead info and defer loading.
    sig do
      params(
        # The record to load the association from
        record: ActiveRecord::Base,
        # The lookahead introspection for this field
        lookahead: GraphQL::Execution::Lookahead
      ).returns(
        # Returns self to conform to dataloader interface
        T.self_type
      )
    end
    def load_with_lookahead(record, lookahead)
      context_visited = context[:visited_lookahead_paths] ||= Set.new
      path_key = [ record.class.name, @association_name ].join(".")

      # Prevent re-visiting nodes
      return load(record) if context_visited.include?(path_key)

      context_visited << path_key
      @object_to_lookahead[record] = lookahead

      load(record)
    end

    # Performs the actual association preload in batch.
    sig do
      override.params(
        # The records passed to `load` or `load_with_lookahead`
        records: T::Array[ActiveRecord::Base]
      ).returns(T::Array[T.untyped])
    end
    def fetch(records)
      # Group records by their class (to handle polymorphism or STI safely)
      grouped = records.group_by(&:class)

      grouped.each do |model_class, model_records|
        # Nested association hash of what we need to preload
        preload_spec = build_combined_preload(model_records)

        # Prevent reloading of the same pattern
        key = [ model_class.name, preload_spec ].hash
        next if @already_preloaded.include?(key)
        @already_preloaded << key

        Rails.logger.debug(
          "[Preload] #{@association_name} for #{model_class.name}: #{preload_spec.inspect}"
        )

        # Ensure we're not trying to preload more direct records than we
        # need to.
        unique_records = deduplicate_by_id(model_records)

        # An internal Rails class that handles eager loading associations. While
        # we typically use `includes`, `preload`, or `eager_load` in ActiveRecord
        # queries, those methods eventually invoke this class under the hood.
        #
        # We invoke this with each group of unique records, as well as the
        # lookahead-tree for what preloads we need to have available.
        #
        # This means that the requested SQL queries are executed in batches
        # imperatively, and then loaded into each record's `association_cache`
        # so it will not require an additional database query.
        #
        # Why use this instead of the above typical preloading mechanisms? This
        # is useful when you do not control the original query and want to load
        # associations lazily after the fact, especitlaly in cases where you
        # want to dynamically compute them like when using lookaheads.
        BatchedPreloader.preload(
          records: unique_records,
          associations: preload_spec
        )
      end

      # Return the preloaded associations
      records.map { |record| record.public_send(@association_name) }
    end

    private

    # Deduplicates records by their database ID to avoid redundant preloads.
    sig { params(records: T::Array[ActiveRecord::Base]).returns(T::Array[ActiveRecord::Base]) }
    def deduplicate_by_id(records)
      records.index_by(&:id).values
    end

    # Combines all lookahead-based preload trees into a unified tree
    # suitable for ActiveRecord’s `.preload` method.
    sig do
      params(
        records: T::Array[ActiveRecord::Base]
      ).returns(
        # a nested structure like:
        #   `:comments` or `{ comments: { author: :profile } }`
        T.untyped
      )
    end
    def build_combined_preload(records)
      lookaheads = records.map { |r| @object_to_lookahead[r] }.compact

      return @association_name if lookaheads.empty?

      preloads = lookaheads.map { |la| build_preload_tree(la, path: []) }.uniq
      preloads.reduce { |merged, next_tree| deep_merge_preloads(merged, next_tree) }
    end

    # Builds a preload structure from the lookahead selections.
    sig do
      params(
        lookahead: GraphQL::Execution::Lookahead,
        path: T::Array[Symbol]
      ).returns(
        # Preload specification for ActiveRecord, similar to `build_combined_preload`'s
        # signature
        T.untyped
      )
    end
    def build_preload_tree(lookahead, path: [])
      # If the top-level association isn’t being queried, return symbol
      return @association_name unless lookahead.selection(@association_name)
      return nil if path.include?(@association_name)

      # Recursively extract nested selection trees for the association
      current_path = path + [ @association_name ]
      children = lookahead
        .selection(@association_name)
        .selections
        .select(&:selections)
        .each_with_object({}) do |selection, result|
          result[selection.name.to_sym] = build_preload_for_selection(
            selection,
            path: current_path
          )
        end

      # Similar to the above, return the symbol if there's no nesting here
      children.any? ? { @association_name => children } : @association_name
    end

    # Recursively builds nested preload trees from lookahead selection objects
    sig do
      params(
        selection: GraphQL::Execution::Lookahead,
        path: T::Array[Symbol]
      ).returns(
        # nested preload tree
        T::Hash[Symbol, T.untyped]
      )
    end
    def build_preload_for_selection(selection, path: [])
      current_path = path + [ @association_name ]

      selection
        .selections
        .select(&:selections)
        .each_with_object({}) do |sub, result|
          # Skip any cases where this path has already been
          # traversed
          next if path.include?(sub.name.to_sym)

          result[sub.name.to_sym] = build_preload_for_selection(
            sub,
            path: current_path
          )
        end
    end

    # Deeply merges two preload trees (either symbol or nested hash form)
    #
    # Examples:
    #   deep_merge_preloads(:comments, :comments) => :comments
    #   deep_merge_preloads({ comments: :author }, { comments: { likes: :user } })
    #   => { comments: { author: nil, likes: :user } }
    sig { params(left: T.untyped, right: T.untyped).returns(T.untyped) }
    def deep_merge_preloads(left, right)
      return right if left == right || left.nil?
      return left if right.nil?

      if left.is_a?(Hash) && right.is_a?(Hash)
        left.merge(right) { |_, lv, rv| deep_merge_preloads(lv, rv) }
      else
        right
      end
    end

    sig { returns(Symbol) }
    attr_reader :association_name

    sig { returns(T.untyped) }
    attr_reader :context
  end
end
