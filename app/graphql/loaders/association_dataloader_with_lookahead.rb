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
  class AssociationDataloaderWithLookahead < GraphQL::Dataloader::Source
    extend T::Sig

    sig { params(association_name: T.any(String, Symbol)).void }
    def initialize(association_name)
      @association_name = association_name.to_sym
      @object_to_lookahead = T.let({}, T::Hash[ActiveRecord::Base, GraphQL::Execution::Lookahead])
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
        ActiveRecord::Associations::Preloader
          .new(records: unique_records, associations: preload_spec)
          .call.tap do
            Rails.logger.debug(
              "[Preloader] Preloaded #{preload_spec} for #{records.first.class.name}"
            )
          end
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
      preloads = lookaheads.map { |la| build_preload_tree(la) }.uniq

      preloads.reduce { |merged, next_tree| deep_merge_preloads(merged, next_tree) }
    end

    # Builds a preload structure from the lookahead selections.
    sig do
      params(
        lookahead: GraphQL::Execution::Lookahead
      ).returns(
        # Preload specification for ActiveRecord, similar to `build_combined_preload`'s
        # signature
        T.untyped
      )
    end
    def build_preload_tree(lookahead)
      # If the top-level association isn’t being queried, return symbol
      return @association_name unless lookahead.selection(@association_name)

      # Recursively extract nested selection trees for the association
      children = lookahead
        .selection(@association_name)
        .selections
        .select(&:selections)
        .each_with_object({}) do |selection, result|
          result[selection.name.to_sym] = build_preload_for_selection(selection)
        end

      # Similar to the above, return the symbol if there's no nesting here
      children.any? ? { @association_name => children } : @association_name
    end

    # Recursively builds nested preload trees from lookahead selection objects
    sig do
      params(
        selection: GraphQL::Execution::Lookahead
      ).returns(
        # nested preload tree
        T::Hash[Symbol, T.untyped]
      )
    end
    def build_preload_for_selection(selection)
      selection
        .selections
        .select(&:selections)
        .each_with_object({}) do |sub, result|
          result[sub.name.to_sym] = build_preload_for_selection(sub)
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
  end
end
