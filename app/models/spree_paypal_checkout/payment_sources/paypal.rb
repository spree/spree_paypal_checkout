module SpreePaypalCheckout
  module PaymentSources
    class Paypal < ::Spree::PaymentSource
      store_accessor :public_metadata, :email, :name, :account_status, :account_id

      def actions
        %w[credit void]
      end

      def self.display_name
        'PayPal'
      end
    end
  end
end
