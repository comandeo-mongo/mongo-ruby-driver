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
    class OperationSpanBuilder
      include OpenTelemetry::Shared

      def build(name, operation, context)
        [
          build_span_name(name, operation),
          build_span_attrs(name, operation, context)
        ]
      end

      private

      def build_span_name(op_name, op)
        if (coll_name = op.spec[:coll_name])
          "#{op_name} #{op.spec[:db_name]}.#{coll_name}"
        else
          op_name
        end
      end

      def build_span_attrs(op_name, op, op_context)
        pp op_context&.in_transaction?
        {
            'db.system' => 'mongodb',
            'db.namespace' => op.spec[:db_name],
            'db.collection.name' => op.spec[:coll_name],
            'db.operation.name' => op_name,
            'db.operation.summary' => build_span_name(op_name, op)
          }
      end
    end
  end
end
