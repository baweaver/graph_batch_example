# typed: strict

module Loaders
  class AssociationDataloaderWithLookahead < GraphQL::Dataloader::Source
    extend T::Sig

    sig { params(association_name: T.any(String, Symbol)).void }
    def initialize(association_name)
      @association_name = association_name.to_sym
      @object_to_lookahead = T.let({}, T::Hash[ActiveRecord::Base, GraphQL::Execution::Lookahead])
    end

    sig do
      params(
        record: ActiveRecord::Base,
        lookahead: GraphQL::Execution::Lookahead
      ).returns(T.self_type)
    end
    def load_with_lookahead(record, lookahead)
      @object_to_lookahead[record] = lookahead
      load(record)
    end

    sig { override.params(records: T::Array[ActiveRecord::Base]).returns(T::Array[T.untyped]) }
    def fetch(records)
      grouped = records.group_by(&:class)

      grouped.each do |model_class, model_records|
        preload_spec = build_combined_preload(model_records)

        Rails.logger.debug("[Preload] #{@association_name} for #{model_class.name}: #{preload_spec.inspect}")

        unique_records = deduplicate_by_id(model_records)

        ActiveRecord::Associations::Preloader
          .new(records: unique_records, associations: preload_spec)
          .call.tap do
            Rails.logger.debug("[Preloader] Preloaded #{preload_spec} for #{records.first.class.name}")
          end
      end

      records.map { |record| record.public_send(@association_name) }
    end

    private

    sig { params(records: T::Array[ActiveRecord::Base]).returns(T::Array[ActiveRecord::Base]) }
    def deduplicate_by_id(records)
      records.index_by(&:id).values
    end

    sig { params(records: T::Array[ActiveRecord::Base]).returns(T.untyped) }
    def build_combined_preload(records)
      lookaheads = records.map { |r| @object_to_lookahead[r] }.compact

      preloads = lookaheads.map { |la| build_preload_tree(la) }.uniq

      preloads.reduce { |merged, next_tree| deep_merge_preloads(merged, next_tree) }
    end

    sig { params(lookahead: GraphQL::Execution::Lookahead).returns(T.untyped) }
    def build_preload_tree(lookahead)
      return @association_name unless lookahead.selection(@association_name)

      children = lookahead
        .selection(@association_name)
        .selections
        .select(&:selections)
        .each_with_object({}) do |selection, result|
          result[selection.name.to_sym] = build_preload_for_selection(selection)
        end

      children.any? ? { @association_name => children } : @association_name
    end

    sig { params(selection: GraphQL::Execution::Lookahead).returns(T::Hash[Symbol, T.untyped]) }
    def build_preload_for_selection(selection)
      selection
        .selections
        .select(&:selections)
        .each_with_object({}) do |sub, result|
          result[sub.name.to_sym] = build_preload_for_selection(sub)
        end
    end

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

    private

    sig { returns(Symbol) }
    attr_reader :association_name
  end
end
