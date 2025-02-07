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
  module OpenTelemetry
    class MethodSpanBuilder
      include OpenTelemetry::Shared

      def build(name, db, collection)
        [
          build_span_name(name, operation),
          build_span_attrs(name, operation, context)
        ]
      end

      private

      def build_span_name(name, db, collection)
        if (collection)
          "#{name} #{db}.#{collection}"
        else
          name
        end
      end

      def build_span_attrs(name, db, collection)
        {
          'db.system' => 'mongodb',
          'db.namespace' => db,
          'db.collection.name' => collection,
          'db.operation.name' => name,
          'db.operation.summary' => build_span_name(name, db, collection)
        }
      end
    end
  end
end
