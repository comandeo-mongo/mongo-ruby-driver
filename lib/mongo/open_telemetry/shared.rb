# frozen_string_literal: true

module Mongo
  module OpenTelemetry
    module Shared
      # @param [ OpenTelemetry::Trace::Span | nil ] span
      # @param [ Mongo::Operation::Result ] result
      def add_attributes_from_result(span, result)
        return if span.nil? || result.nil?

        if result.successful?
          if result.has_cursor_id? && (cursor_id = result.cursor_id).positive?
            span.add_attributes(
              'db.mongodb.cursor_id' => cursor_id
            )
          end
        else
          span.record_exception(result.error)
        end
      end
    end
  end
end
