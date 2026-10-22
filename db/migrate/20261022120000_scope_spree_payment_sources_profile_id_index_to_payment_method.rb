class ScopeSpreePaymentSourcesProfileIdIndexToPaymentMethod < ActiveRecord::Migration[7.2]
  def change
    remove_index :spree_payment_sources, [:type, :gateway_payment_profile_id],
                 unique: true, name: 'index_payment_sources_on_type_and_gateway_payment_profile_id'
    add_index :spree_payment_sources, [:type, :payment_method_id, :gateway_payment_profile_id],
              unique: true, name: 'index_payment_sources_on_type_payment_method_and_profile_id'
  end
end
