class OrdersController < ApplicationController
  before_action :authenticate_user!

  def show
    @order = Order.find(params[:id])
    @products = Product.all

    # subtotal is an instance method in order.rb
    @order_subtotal = @order.subtotal
    @discount_options = [['5%', 5], ['10%', 10], ['20%', 20]]

    # Payment options
    @payment_options = [['Cash', 'cash'], ['PayPay', 'paypay'], ["Credit Card", "credit_card"]]
    @qr_code_url = create_qr_code

  end

  def index
    @current_page = 'orders'
    @orders = current_user.orders
    @order = @orders.where(status: "incomplete").last
    # @transaction = params[:order][:merchantPaymentId]
  end

  def edit
    @current_page = 'edit_order'
    @products = current_user.products

    @order = current_user.orders.where(status: "incomplete").order(:created_at).last || Order.create(user: current_user)
    @success_status = params[:success] == "true"
    @order = @order.process! if @success_status
    @orders = Order.all

    # if @orders.last&.status == "incomplete"
    #   @order = @orders.last
    # else
    #   @order = Order.new
    #   @order.save
    # end
    # redirect_to order_path(@orders.last) if @orders.last&.status == "incomplete"
  end

  def update
    @order = Order.find(params[:id])
    # @last_complete_order = Order.find(params[:id].to_i - 1)
    # @event = Event.where('start_date >= ? AND end_date <= ?', @last_complete_order.updated_at.beginning_of_day, @last_complete_order.updated_at.end_of_day)[0]
    @event = Event.where('start_date <= ? AND end_date >= ?', @order.updated_at, @order.updated_at).first
    # @last_complete_order.update(event: @event)

    @order.order_products.each do |op|
      if op.product_quantity <= 0
        op.destroy
      end
    @order.event = @event
    @order.save
    end

    @payment_option = params[:order][:payment_option]
    if @payment_option == "paypay"
      redirect_to action: :create_qr_code
      return
      # redirect_to controller: :controller_name, action: :action_name
    end

    # update_inventory is an instance method in order.rb
    @order.update_inventory

    # mark order as complete and order's total price (inclusive of discount selected)
    @discount = params[:order][:order_discount].to_i.fdiv(100) * @order.subtotal
    @order_total_price = @order.subtotal - @discount
    @order.update(status: "completed", total_price: @order_total_price, order_discount: @discount)

    # create a new empty order
    @last_order = Order.new(total_price: 0, user: current_user)
    @last_order.save

    # flash message in redirected page
    flash[:notice] = "Payment successfull!"

    # redirect to new order
    redirect_to edit_order_path(@last_order)
  end


  private

  def create_qr_code
    require './lib/api_clients/pay_pay'
    @order = Order.find(params[:id])
    redirect_url = edit_order_url(@order, host: ENV["APP_DOMAIN"] || "localhost", params: {success: true})


    builder = PayPay::QrCodeCreateBuilder.new(redirect_url)
    builder.merchantPaymentId
    # addItem(name, category, quantity, product_id, unit_amount)


    @order.order_products.where.not(product_quantity: 0).each do |op|
      builder.addItem(op.product.name, op.product.category, op.product_quantity, op.product_id, op.product_price_at_sale)
    end

    begin
      client = PayPay::Client.new(ENV['API_KEY'], ENV['API_SECRET'], ENV['MERCHANT_ID'])
      response = client.qr_code_create(builder.finish)
      response_body = JSON.parse(response.body)
      response_body.dig("data", "url")
    rescue JSON::ParserError => e
      p "JSON parsing failed: #{e.message}"
    end
    # redirect_to @qr_code_url, allow_other_host: true
  end

end
