module Loaders
  class AssociationDataloaderWithLookahead < GraphQL::Dataloader::Source
    def initialize(association_name)
      @association_name = association_name.to_sym
      @object_to_lookahead = {}
    end

    # Custom loader that saves lookahead per object
    def load_with_lookahead(record, lookahead)
      @object_to_lookahead[record] = lookahead
      load(record)
    end

    def fetch(records)
      grouped = records.group_by(&:class)

      grouped.each do |model_class, model_records|
        preload_spec = build_combined_preload(model_records)

        Rails.logger.debug("[Preload] #{@association_name} for #{model_class.name}: #{preload_spec.inspect}")

        unique_records = deduplicate_by_id(model_records)

        ActiveRecord::Associations::Preloader
          .new(records: unique_records, associations: preload_spec)
          .call
      end

      records.map { |record| record.public_send(@association_name) }
    end

    private

    def deduplicate_by_id(records)
      records.index_by(&:id).values
    end

    def build_combined_preload(records)
      lookaheads = records.map { |r| @object_to_lookahead[r] }.compact

      preloads = lookaheads.map { |la| build_preload_tree(la) }.uniq

      preloads.reduce { |merged, next_tree| deep_merge_preloads(merged, next_tree) }
    end

    def build_preload_tree(lookahead)
      return @association_name unless lookahead&.selection(@association_name)

      children = lookahead
        .selection(@association_name)
        .selections
        .select(&:selections) # fields with sub-selections
        .each_with_object({}) do |selection, result|
          result[selection.name.to_sym] = build_preload_for_selection(selection)
        end

      children.any? ? { @association_name => children } : @association_name
    end

    def build_preload_for_selection(selection)
      selection
        .selections
        .select(&:selections) # nested object fields
        .each_with_object({}) do |sub, result|
          result[sub.name.to_sym] = build_preload_for_selection(sub)
        end
    end

    def deep_merge_preloads(left, right)
      return right if left == right || left.nil?
      return left if right.nil?

      if left.is_a?(Hash) && right.is_a?(Hash)
        left.merge(right) { |_, lv, rv| deep_merge_preloads(lv, rv) }
      else
        right
      end
    end
  end
end
