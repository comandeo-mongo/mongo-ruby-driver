# frozen_string_literal: true

#
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
    # This class is used to build +db.statement+ attribute for an OpenTelemetry span
    # from a MongoDB command.
    class StatementBuilder
      # @param [ BSON::Document ] command The message that will be
      #   sent to the server.
      def initialize(command)
        @command = command
        @command_name, @collection = command.first
      end

      # Builds the statement.
      #
      # @return [ String ] The statement as a JSON string.
      def build
        statement.to_json.freeze unless statement.empty?
      end

      private

      def statement
        mask(@command)
      end

      def mask(hash)
        hash.reject { |k, v| Mongo::Protocol::Msg::INTERNAL_KEYS.include?(k.to_s) }
      end
    end
  end
end
