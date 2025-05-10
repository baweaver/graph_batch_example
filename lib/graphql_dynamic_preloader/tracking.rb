# lib/graphql_dynamic_preloader/tracking.rb
module GraphqlDynamicPreloader
  module Tracking
    def self.fetch(record:, association:, context:)
      raise ArgumentError, "Missing GraphqlDynamicPreloader::Context" unless context.is_a?(GraphqlDynamicPreloader::Context)

      context.track_association(record: record, association: association)
      record.public_send(association)
    end
  end
end
