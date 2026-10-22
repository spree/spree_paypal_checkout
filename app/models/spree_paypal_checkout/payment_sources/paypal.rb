module SpreePaypalCheckout
  module PaymentSources
    class Paypal < ::Spree::PaymentSource
      store_accessor :private_metadata, :email, :name, :account_status, :account_id

      # Spree::PaymentSource validates gateway_payment_profile_id as unique per type only.
      # For PayPal that value is the buyer's account_id, which is the same across every merchant,
      # so the same buyer needs a separate source for each PayPal payment method.
      validators_on(:gateway_payment_profile_id).grep(ActiveRecord::Validations::UniquenessValidator).each do |validator|
        skip_callback(:validate, validator)
        _validators[:gateway_payment_profile_id].delete(validator)
      end

      validates :gateway_payment_profile_id, uniqueness: { scope: %i[type payment_method_id] }

      def actions
        %w[credit void]
      end

      def self.display_name
        'PayPal'
      end
    end
  end
end
