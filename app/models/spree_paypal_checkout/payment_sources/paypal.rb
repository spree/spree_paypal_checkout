module SpreePaypalCheckout
  module PaymentSources
    class Paypal < ::Spree::PaymentSource
      store_accessor :public_metadata, :email, :name

      def actions
        %w[credit void]
      end

      def self.display_name
        'PayPal'
      end
    end
  end
end
