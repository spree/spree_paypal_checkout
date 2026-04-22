Spree::Core::Engine.add_routes do
  # Storefront API v2 (only when spree_legacy_api_v2 gem is available)
  if defined?(SpreeLegacyApiV2::Engine)
    namespace :api, defaults: { format: 'json' } do
      namespace :v2 do
        namespace :storefront do
          resources :paypal_orders, only: [:create] do
            member do
              put :capture
            end
          end
        end
      end
    end
  end
end
