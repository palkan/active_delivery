# frozen_string_literal: true

module ActionMailer
  # See https://api.rubyonrails.org/classes/ActionMailer/Parameterized.html
  module Parameterized
    extend ActiveSupport::Concern

    included do
      attr_accessor :params
    end

    module ClassMethods
      # Provide the parameters to the mailer in order to use them in the instance methods and callbacks.
      #
      #   InvitationsMailer.with(inviter: person_a, invitee: person_b).account_invitation.deliver_later
      #
      # See Parameterized documentation for full example.
      def with(params)
        ActionMailer::Parameterized::Mailer.new(self, params)
      end
    end

    class Mailer # :nodoc:
      def initialize(mailer, params)
        @mailer, @params = mailer, params
      end

      private

      def method_missing(method_name, *args)
        if @mailer.action_methods.include?(method_name.to_s)
          ActionMailer::Parameterized::MessageDelivery.new(@mailer, method_name, @params, *args)
        else
          super
        end
      end

      def respond_to_missing?(method, include_all = false)
        @mailer.respond_to?(method, include_all)
      end
    end

    class MessageDelivery < ActionMailer::MessageDelivery # :nodoc:
      def initialize(mailer_class, action, params, *args)
        super(mailer_class, action, *args)
        @mailer ||= mailer_class
        @mail_method ||= action
        @params = params
      end

      def __getobj__ # :nodoc:
        @obj ||= processed_mailer.message
      end

      def processed?
        @processed_mailer || @obj
      end

      private

      def processed_mailer
        @processed_mailer ||= @mailer.send(*mailer_args).tap do |m|
          m.params = @params
          m.process @mail_method, *@args
        end
      end

      def mailer_args
        (ActionMailer::VERSION::MAJOR < 5) ? [:new, nil, *@args] : [:new]
      end

      def enqueue_delivery(delivery_method, options = {})
        if processed?
          super
        else
          args = @mailer.name, @mail_method.to_s, delivery_method.to_s, @params, *@args
          ActionMailer::Parameterized::DeliveryJob.set(options).perform_later(*args)
        end
      end
    end

    class DeliveryJob < ActionMailer::DeliveryJob # :nodoc:
      def perform(mailer, mail_method, delivery_method, params, *args)
        mailer.constantize.with(params).public_send(mail_method, *args).send(delivery_method)
      end
    end
  end
end

ActiveSupport.on_load(:action_mailer) do
  include ActionMailer::Parameterized
end
