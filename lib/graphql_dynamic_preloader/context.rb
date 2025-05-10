# lib/graphql_dynamic_preloader/context.rb
module GraphqlDynamicPreloader
  class Context
    def initialize
      @tracked_associations = Hash.new { |h, k| h[k] = Set.new }
      @records_by_class = Hash.new { |h, k| h[k] = [] }
    end

    attr_reader :tracked_associations, :records_by_class

    def track_association(record:, association:)
      klass = record.class
      @tracked_associations[klass] << association
      register_record(record: record)
    end

    def register_record(record:)
      @records_by_class[record.class] << record
    end

    def preload_all
      @tracked_associations.each do |klass, associations|
        records = @records_by_class[klass]
        next if records.blank? || associations.blank?

        ActiveRecord::Associations::Preloader.new.preload(records.uniq, associations.to_a)
      end
    end
  end
end
