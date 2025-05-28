Spree::Core::Engine.add_routes do
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
