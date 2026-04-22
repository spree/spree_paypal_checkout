module SpreePaypalCheckout
  class Configuration < Spree::Preferences::Configuration
    preference :use_legacy_api, :boolean, default: false
  end
end
