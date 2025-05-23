# frozen_string_literal: true
# rubocop:todo all

# Copyright (C) 2019-2020 MongoDB Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  module Crypt

    # A wrapper around mongocrypt_ctx_t, which manages the
    # state machine for encryption and decription.
    #
    # This class is a superclass that defines shared methods
    # amongst contexts that are initialized for different purposes
    # (e.g. data key creation, encryption, explicit encryption, etc.)
    #
    # @api private
    class Context
      extend Forwardable

      def_delegators :@mongocrypt_handle, :kms_providers

      #  Create a new Context object
      #
      # @param [ Mongo::Crypt::Handle ] mongocrypt_handle A handle to libmongocrypt
      #   used to create a new context object.
      # @param [ ClientEncryption::IO ] io An instance of the IO class
      #   that implements driver I/O methods required to run the
      #   state machine.
      def initialize(mongocrypt_handle, io)
        @mongocrypt_handle = mongocrypt_handle
        # Ideally, this level of the API wouldn't be passing around pointer
        # references between objects, so this method signature is subject to change.

        # FFI::AutoPointer uses a custom release strategy to automatically free
        # the pointer once this object goes out of scope
        @ctx_p = FFI::AutoPointer.new(
          Binding.mongocrypt_ctx_new(@mongocrypt_handle.ref),
          Binding.method(:mongocrypt_ctx_destroy)
        )
        @encryption_io = io
        @cached_azure_token = nil
      end

      attr_reader :ctx_p

      # Returns the state of the mongocrypt_ctx_t
      #
      # @return [ Symbol ] The context state
      def state
        Binding.mongocrypt_ctx_state(@ctx_p)
      end

      # Runs the mongocrypt_ctx_t state machine and handles
      # all I/O on behalf of
      #
      # @param [ CsotTimeoutHolder ] timeout_holder CSOT timeouts for the
      #   operation the state.
      #
      # @return [ BSON::Document ] A BSON document representing the outcome
      #   of the state machine. Contents can differ depending on how the
      #   context was initialized..
      #
      # @raise [ Error::CryptError ] If the state machine enters the
      #   :error state
      #
      # This method is not currently unit tested. It is integration tested
      # in spec/integration/explicit_encryption_spec.rb
      def run_state_machine(timeout_holder)
        while true
          timeout_ms = timeout_holder.remaining_timeout_ms!
          case state
          when :error
            Binding.check_ctx_status(self)
          when :ready
            # Finalize the state machine and return the result as a BSON::Document
            return Binding.ctx_finalize(self)
          when :done
            return nil
          when :need_mongo_keys
            provide_keys(timeout_ms)
          when :need_mongo_collinfo
            provide_collection_info(timeout_ms)
          when :need_mongo_markings
            provide_markings(timeout_ms)
          when :need_kms
            feed_kms
          when :need_kms_credentials
            Binding.ctx_provide_kms_providers(
              self,
              retrieve_kms_credentials(timeout_holder).to_document
            )
          else
            raise Error::CryptError.new(
              "State #{state} is not supported by Mongo::Crypt::Context"
            )
          end
        end
      end

      private

      def provide_markings(timeout_ms)
        cmd = Binding.ctx_mongo_op(self)

        result = @encryption_io.mark_command(cmd, timeout_ms: timeout_ms)
        mongocrypt_feed(result)

        mongocrypt_done
      end

      def provide_collection_info(timeout_ms)
        filter = Binding.ctx_mongo_op(self)

        result = @encryption_io.collection_info(@db_name, filter, timeout_ms: timeout_ms)
        mongocrypt_feed(result) if result

        mongocrypt_done
      end

      def provide_keys(timeout_ms)
        filter = Binding.ctx_mongo_op(self)

        @encryption_io.find_keys(filter, timeout_ms: timeout_ms).each do |key|
          mongocrypt_feed(key) if key
        end

        mongocrypt_done
      end

      def feed_kms
        while (kms_context = Binding.ctx_next_kms_ctx(self)) do
          begin
            delay = Binding.kms_ctx_usleep(kms_context)
            sleep(delay / 1_000_000.0) unless delay.nil?
            provider = Binding.kms_ctx_get_kms_provider(kms_context)
            tls_options = @mongocrypt_handle.kms_tls_options(provider)
            @encryption_io.feed_kms(kms_context, tls_options)
          rescue Error::KmsError => e
            if e.network_error?
              if Binding.kms_ctx_fail(kms_context)
                next
              else
                raise
              end
            else
              raise
            end
          end
        end
        Binding.ctx_kms_done(self)
      end

      # Indicate that state machine is done feeding I/O responses back to libmongocrypt
      def mongocrypt_done
        Binding.mongocrypt_ctx_mongo_done(ctx_p)
      end

      # Feeds the result of a Mongo operation back to libmongocrypt.
      #
      # @param [ Hash ] doc BSON document to feed.
      #
      # @return [ BSON::Document ] BSON document containing the result.
      def mongocrypt_feed(doc)
        Binding.ctx_mongo_feed(self, doc)
      end

      # Retrieves KMS credentials for providers that are configured
      # for automatic credentials retrieval.
      #
      # @param [ CsotTimeoutHolder ] timeout_holder CSOT timeout.
      #
      # @return [ Crypt::KMS::Credentials ] Credentials for the configured
      #   KMS providers.
      def retrieve_kms_credentials(timeout_holder)
        providers = {}
        if kms_providers.aws&.empty?
          begin
            aws_credentials = Mongo::Auth::Aws::CredentialsRetriever.new.credentials(timeout_holder)
          rescue Auth::Aws::CredentialsNotFound
            raise Error::CryptError.new(
              "Could not locate AWS credentials (checked environment variables, ECS and EC2 metadata)"
            )
          end
          providers[:aws] = aws_credentials.to_h
        end
        if kms_providers.gcp&.empty?
          providers[:gcp] = { access_token: gcp_access_token(timeout_holder) }
        end
        if kms_providers.azure&.empty?
          providers[:azure] = { access_token: azure_access_token(timeout_holder) }
        end
        KMS::Credentials.new(providers)
      end

      # Retrieves a GCP access token.
      #
      # @return [ String ] A GCP access token.
      #
      # @raise [ Error::CryptError ] If the GCP access token could not be
      def gcp_access_token(timeout_holder)
        KMS::GCP::CredentialsRetriever.fetch_access_token(timeout_holder)
      rescue KMS::CredentialsNotFound => e
        raise Error::CryptError.new(
          "Could not locate GCP credentials: #{e.class}: #{e.message}"
        )
      end

      # Returns an Azure access token, retrieving it if necessary.
      #
      # @return [ String ] An Azure access token.
      #
      # @raise [ Error::CryptError ] If the Azure access token could not be
      #   retrieved.
      def azure_access_token(timeout_holder)
        if @cached_azure_token.nil? || @cached_azure_token.expired?
          @cached_azure_token = KMS::Azure::CredentialsRetriever.fetch_access_token(timeout_holder: timeout_holder)
        end
        @cached_azure_token.access_token
      rescue KMS::CredentialsNotFound => e
        raise Error::CryptError.new(
          "Could not locate Azure credentials: #{e.class}: #{e.message}"
        )
      end
    end
  end
end
