# frozen_string_literal: true

# Copyright (C) 2015-present MongoDB Inc.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  class OpenTelemetry
    # This is a wrapper around OpenTelemetry tracer that provides a convenient
    # interface for creating spans.
    class Tracer
      # Environment variable that enables otel instrumentation.
      ENV_VARIABLE_DISABLED = 'OTEL_RUBY_INSTRUMENTATION_MONGODB_DISABLED'

      # Environment variable that controls the db.statement attribute.
      ENV_VARIABLE_QUERY_TEXT = 'OTEL_RUBY_INSTRUMENTATION_MONGODB_QUERY_TEXT'

      # Name of the tracer.
      OTEL_TRACER_NAME = 'mongo-ruby-driver'

      # @return [ OpenTelemetry::SDK::Trace::Tracer | nil ] The otel tracer.
      attr_reader :ot_tracer

      def initialize
        return unless defined?(::OpenTelemetry)
        return if %w[ 1 yes true ].include?(ENV[ENV_VARIABLE_DISABLED])

        @ot_tracer = ::OpenTelemetry.tracer_provider.tracer(
          OTEL_TRACER_NAME,
          Mongo::VERSION
        )
      end

      def trace_message(command, address, &block)
        in_span(span_name(command), build_attributes(command, address), &block)
      end

      def add_query_text(span, message)
        return unless span && query_text?

        span.add_attributes(
          'db.query.text' => StatementBuilder.new(message.payload[:command]).build
        )
      end

      # @param [ OpenTelemetry::Trace::Span | nil ] span
      # @param [ Mongo::Operation::Result ] result
      def add_attributes_from_result(span, result)
        return if span.nil?

        if result.successful?
          if (cursor_id = result.cursor_id).positive?
            span.add_attributes(
              'db.mongodb.cursor_id' => cursor_id
            )
          end
        else
          span.record_exception(result.error)
        end
      end

      private

      def in_span(name, attributes = {}, &block)
        if enabled?
          @ot_tracer.in_span(name, attributes: attributes, kind: :client, &block)
        else
          yield
        end
      end

      # @return [ true, false ] Whether otel instrumentation is enabled.
      def enabled?
        @ot_tracer != nil
      end

      def query_text?
        %w[ 1 yes true ].include?(ENV[ENV_VARIABLE_QUERY_TEXT])
      end

      # @return [ String ] The name of the span.
      def span_name(command)
        collection = collection_name(command)
        command_name = command.keys.first
        if collection
          "#{collection}.#{command_name}"
        else
          command_name
        end
      end

      # @return [ Hash ] The attributes of the span.
      def build_attributes(command, address)
        command_name = command.keys.first
        {
          'db.system' => 'mongodb',
          'db.namespace' => command['$db'],
          'db.operation.name' => command_name,
          'server.port' => address.port,
          'net.peer.port' => address.port,
          'server.address' => address.host,
          'net.peer.address' => address.host,
          'db.query.summary' => span_name(command)
        }.tap do |attributes|
          if (coll_name = collection_name(command))
            attributes['db.collection.name'] = coll_name
          end
          if command_name == 'getMore'
            attributes['db.mongodb.cursor_id'] = command[command_name].value
          end
        end
      end

      # @return [ String | nil] Name of collection the operation is executed on.
      def collection_name(command)
        command.values.first if command.values.first.is_a?(String)
      end
    end
  end
end
