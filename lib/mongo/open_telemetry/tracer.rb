# frozen_string_literal: true

# Copyright (C) 2025-present MongoDB Inc.
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

require 'singleton'

module Mongo
  module OpenTelemetry
    class Tracer
      include Singleton

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

      # @param [ String ] name Name of the span.
      # @param [ Hash ] attributes Span attributes.
      def in_span(name, attributes: {}, &block)
        if enabled?
          @ot_tracer.in_span(name, attributes: attributes, kind: :client) do |span, context|
            OpenTelemetry.set_current(span, context)
            yield(span, context) if block_given?
          ensure
            OpenTelemetry.clear_current
          end
        else
          yield
        end
      end

      # @param [ String ] name Name of the span.
      # @param [ Hash ] attributes Span attributes.
      # @param [ OpenTelemetry::API ]
      def start_span(name, attributes: {}, with_parent: nil, &block)
        return unless enabled?

        @ot_tracer.start_span(name, with_parent: with_parent, attributes: attributes, &block)
      end

      # @return [ Boolean ] whether OpenTelemetry tracing is enabled.
      def enabled?
        @ot_tracer != nil
      end

      # @return [ Boolean ] whether query_text should be added.
      def query_text?
        %w[ 1 yes true ].include?(ENV[ENV_VARIABLE_QUERY_TEXT])
      end

    end
  end
end
