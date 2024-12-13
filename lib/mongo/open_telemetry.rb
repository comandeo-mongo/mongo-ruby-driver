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
  # Container class for OpenTelemetry functionality.
  #
  # @api private
  class OpenTelemetry
    def self.tracer
      @tracer ||= Tracer.new
    end
  end
end

require 'mongo/open_telemetry/statement_builder'
require 'mongo/open_telemetry/tracer'
