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

      def build(name, operation)
        attrs = {
            'db.system' => 'mongodb',
            'db.namespace' => operation.spec[:db_name],
            'db.collection.name' => operation.spec[:coll_name],
            'db.operation.name' => name,
            'db.operation.summary' => "#{name} #{operation.spec[:coll_name]}"
          }

        [name, attrs]
      end
    end
  end
end
