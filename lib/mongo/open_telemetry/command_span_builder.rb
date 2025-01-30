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
    class CommandSpanBuilder

      def build(command, address)
        [ span_name(command), build_attributes(command, address) ]
      end

      private

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
          'db.command.name' => command_name,
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
