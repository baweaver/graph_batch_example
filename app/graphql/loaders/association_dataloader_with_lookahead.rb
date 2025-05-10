# app/graphql/loaders/association_dataloader_with_lookahead.rb
# frozen_string_literal: true

module Loaders
  class AssociationDataloaderWithLookahead < GraphQL::Dataloader::Source
    def initialize(association_name, lookahead)
      @association_name = association_name.to_sym
      @lookahead = lookahead
    end

    def fetch(records)
      grouped = records.group_by(&:class)

      preload_spec = build_preload(@lookahead)

      Rails.logger.info do
        "AssociationDataloader: preloading #{@association_name} with preload spec: #{preload_spec.inspect}"
      end

      grouped.each do |model_class, model_records|
        reflection = model_class.reflect_on_association(@association_name)

        unless reflection
          raise ArgumentError, "Association #{@association_name} not found on #{model_class.name}"
        end

        # Polymorphic handling: group by reflection's klass if polymorphic
        if reflection.polymorphic?
          Rails.logger.info "AssociationDataloader: handling polymorphic association #{@association_name} for #{model_class.name}"

          # Further group records by their associated type
          model_records.group_by { |record| record.public_send(reflection.foreign_type) }.each do |type_name, type_records|
            next if type_name.nil?

            type_class = type_name.safe_constantize
            next unless type_class

            unique_records = deduplicate_by_id(type_records)
            preload_for(type_class, unique_records, preload_spec)
          end
        else
          unique_records = deduplicate_by_id(model_records)
          preload_for(model_class, unique_records, preload_spec)
        end
      end

      # Return the root association result for each record
      records.map do |record|
        record.public_send(@association_name)
      end
    end

    private

    def deduplicate_by_id(records)
      records.each_with_object({}) do |record, result|
        id = record.id
        next if id.nil?
        result[id] ||= record
      end.values
    end

    def preload_for(model_class, records, preload_spec)
      Rails.logger.info "AssociationDataloader: preloading for #{model_class.name} with #{records.size} records and spec: #{preload_spec.inspect}"
      ActiveRecord::Associations::Preloader.new(records:, associations: preload_spec).call
    end

    # Recursively builds preload spec from lookahead
    def build_preload(lookahead)
      return @association_name if lookahead.nil?

      child_preloads = lookahead.selection(@association_name)&.selections&.each_with_object({}) do |selection, result|
        next unless association?(selection)
        nested_preload = build_preload_for_selection(selection)
        result[selection.name.to_sym] = nested_preload if nested_preload
      end

      if child_preloads&.any?
        { @association_name => child_preloads }
      else
        @association_name
      end
    end

    def build_preload_for_selection(selection)
      sub_preloads = selection.selections.each_with_object({}) do |sub_selection, result|
        next unless association?(sub_selection)
        deeper_preload = build_preload_for_selection(sub_selection)
        result[sub_selection.name.to_sym] = deeper_preload if deeper_preload
      end

      sub_preloads.any? ? sub_preloads : {}
    end

    # Heuristic: treat as association if it has sub-selections (likely an object type)
    def association?(selection)
      selection.selections.any?
    end
  end
end
