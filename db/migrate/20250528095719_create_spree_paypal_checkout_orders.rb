class CreateSpreePaypalCheckoutOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_paypal_checkout_orders do |t|
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }
      t.string :paypal_order_id, null: false, index: { unique: true }
      t.string :status, null: false
      t.datetime :captured_at

      if t.respond_to? :jsonb
        t.jsonb :data
      else
        t.json :data
      end

      t.timestamps
    end
  end
end
