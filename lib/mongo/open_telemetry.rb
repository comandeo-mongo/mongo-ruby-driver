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

module Mongo
  # @api private
  module OpenTelemetry
    def tracer
      Tracer.instance
    end
    module_function :tracer

    def set_current(span, context)
      Thread.current['mongo-ruby-driver-otel-span'] = span
      Thread.current['mongo-ruby-driver-otel-context'] = context
    end
    module_function :set_current

    def current_span
      Thread.current['mongo-ruby-driver-otel-span']
    end
    module_function :current_span

    def current_context
      Thread.current['mongo-ruby-driver-otel-context']
    end
    module_function :current_context

    def clear_current
      Thread.current['mongo-ruby-driver-otel-context'] = nil
      Thread.current['mongo-ruby-driver-otel-span'] = nil
    end
    module_function :clear_current
  end
end

require 'mongo/open_telemetry/command_span_builder'
require 'mongo/open_telemetry/operation_span_builder'
require 'mongo/open_telemetry/tracer'
