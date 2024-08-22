class Order < ApplicationRecord
  # belongs_to :event
  has_many :order_products
  has_many :products, through: :order_products

  validates :total_price, presence: true
  validates :status, presence: true
  OPTIONS = ["incomplete", "completed"]
  validates :status, inclusion: { in: OPTIONS }

  def subtotal
    subtotal = 0
    self.order_products.each do |op|
      product_total = op.product_price_at_sale * op.product_quantity
      subtotal = subtotal + product_total
    end
    return subtotal
  end

  def update_inventory
    self.order_products.each do |op|
      qty_bought = op.product_quantity
      product_to_update = op.product
      qty_to_update = product_to_update.quantity
      product_to_update.update(quantity: qty_to_update - qty_bought)
    end
  end

  def add_one_to_cart(product, current_cart_qty)
    if product.quantity > current_cart_qty.to_i
      return current_cart_qty + 1
    else
      "cannot add"
    end
  end
end
