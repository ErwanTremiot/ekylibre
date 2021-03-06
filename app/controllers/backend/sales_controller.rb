# -*- coding: utf-8 -*-
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::SalesController < BackendController
  manage_restfully only: []

  respond_to :csv, :ods, :xlsx, :pdf, :odt, :docx, :html, :xml, :json

  unroll

  # management -> sales_conditions
  def self.sales_conditions
    code = ""
    code = search_conditions(:sales => [:pretax_amount, :amount, :number, :initial_number, :description], :entities => [:number, :full_name]) + " ||= []\n"
    code << "unless params[:s].blank?\n"
    code << "  if params[:s] == 'all'\n"
    code << "    c[0] += \" AND state IN ('estimate', 'order', 'invoice')\"\n"
    # code << "  elsif params[:s] == 'unpaid'\n"
    # code << "    c[0] += \" AND state IN ('order', 'invoice') AND paid_amount < amount AND lost = ?\"\n"
    # code << "    c << false\n"
    code << "  end\n "
    code << "  if params[:responsible_id].to_i > 0\n"
    code << "    c[0] += \" AND \#{Sale.table_name}.responsible_id = ?\"\n"
    code << "    c << params[:responsible_id]\n"
    code << "  end\n"
    code << "end\n "
    code << "c\n "
    return code.c
  end

  list(conditions: sales_conditions, joins: :client, order: {created_at: :desc, number: :desc}) do |t| # , :line_class => 'RECORD.tags'
    t.column :number, url: {action: :show, step: :default}
    t.column :created_at
    t.column :invoiced_at
    t.column :client, url: true
    t.column :responsible, hidden: true
    t.column :description, hidden: true
    t.status
    t.column :state_label
    t.column :amount, currency: true
    # t.action :show, url: {format: :pdf}, image: :print
    t.action :edit, if: :draft?
    t.action :cancel, if: :cancelable?
    t.action :destroy, if: :aborted?
  end

  # Displays the main page with the list of sales
  def index
    respond_to do |format|
      format.html
      format.xml  { render :xml => @sales }
      # format.pdf  { render_print_sales(params[:established_at]||Date.today) }
      format.pdf  { render :pdf => @sales, :with => params[:template] }
      # format.odt  { render_print_sales(params[:established_at]||Date.today) }
      # format.docx { render_print_sales(params[:established_at]||Date.today) }
    end
  end

  list(:credits, model: :sales, conditions: {:origin_id => 'params[:id]'.c }, :children => :items) do |t|
    t.column :number, url: true, :children => :designation
    t.column :client, children: false
    t.column :created_at, children: false
    t.column :pretax_amount, currency: true
    t.column :amount, currency: true
  end

  list(:deliveries, model: :outgoing_deliveries, :children => :items, conditions: {:sale_id => 'params[:id]'.c}) do |t|
    t.column :number, :children => :product_name
    t.column :transporter, children: false, url: true
    t.column :address, label_method: :coordinate, children: false
    # t.column :planned_at, children: false
    # t.column :moved_at, children: false
    t.column :population
    # t.column :pretax_amount, currency: true
    # t.column :amount, currency: true
    t.action :edit, if: :updateable?
    t.action :destroy, if: :destroyable?
  end

  # list(:payment_uses, model: :incoming_payment_uses, conditions: ["#{IncomingPaymentUse.table_name}.expense_id=? AND #{IncomingPaymentUse.table_name}.expense_type=?", 'params[:id]'.c, 'Sale']) do |t|
  #   t.column :number, through: :payment, url: true
  #   t.column :amount, currency: true, through: :payment, :label => "payment_amount", url: true
  #   t.column :amount, currency: true
  #   t.column :payment_way
  #   t.column :scheduled, through: :payment, :datatype => :boolean, :label => :column
  #   t.column :downpayment
  #   # t.column :paid_at, through: :payment, :label => :column, :datatype => :date
  #   t.column :to_bank_at, through: :payment, :label => :column, :datatype => :date
  #   t.action :destroy
  # end

  list(:subscriptions, conditions: {:sale_id => 'params[:id]'.c}) do |t|
    t.column :number
    t.column :nature
    t.column :subscriber, url: true
    t.column :address
    t.column :start
    t.column :finish
    t.column :quantity
    t.action :edit
    t.action :destroy
  end

  list(:undelivered_items, model: :sale_items, conditions: {:sale_id => 'params[:id]'.c, :reduced_item_id => nil}) do |t|
    t.column :name, through: :variant
    # t.column :pretax_amount, currency: true, through: :price
    t.column :quantity
    # t.column :unit
    # t.column :pretax_amount, :currency => true
    t.column :amount
    # t.column :undelivered_quantity, :datatype => :decimal
  end

  list(:items, model: :sale_items, conditions: {:sale_id => 'params[:id]'.c}, order: :position, :export => false, :line_class => "((RECORD.variant.subscribing? and RECORD.subscriptions.sum(:quantity) != RECORD.quantity) ? 'warning' : '')".c, :include => [:variant, :subscriptions]) do |t|
    # t.column :name, through: :variant
    # t.column :position
    t.column :label
    #t.column :annotation
    # t.column :serial_number, through: :variant, url: true
    t.column :quantity
    t.column :unit_name
    t.column :unit_price_amount
    t.column :pretax_amount, currency: true
    t.column :amount, currency: true
    # t.action :edit, if: 'RECORD.sale.draft? and RECORD.reduction_origin_id.nil? '
    # t.action :destroy, if: 'RECORD.sale.draft? and RECORD.reduction_origin_id.nil? '
  end

  # Displays details of one sale selected with +params[:id]+
  def show
    return unless @sale = find_and_check
    @sale.other_deals
    respond_with(@sale, :methods => [:taxes_amount, :affair_closed, :client_number],
                        :include => {:address => {:methods => [:mail_coordinate]},
                                     :supplier => {:methods => [:picture_path], :include => {:default_mail_address => {:methods => [:mail_coordinate]}}},
                                     :credits => {},
                                     :invoice_address => {:methods => [:mail_coordinate]},
                                     :items => {:methods => [:taxes_amount, :tax_name], :include => [:variant, :price]}
                                     }
                                     ) do |format|
      format.html do
        session[:current_sale_id] = @sale.id
        session[:current_currency] = @sale.currency
        if params[:step] and not ["products", "deliveries", "summary"].include? params[:step]
          state  = @sale.state
          params[:step] = (@sale.invoice? ? :summary : @sale.order? ? :deliveries : :products).to_s
        end
        if params[:step] == "deliveries"
          if @sale.deliveries.size <= 0 and @sale.order? and @sale.has_content?
            redirect_to controller: :outgoing_deliveries, action: :new, :sale_id => @sale.id
          elsif @sale.deliveries.size <= 0 and @sale.invoice?
            notify(:sale_already_invoiced)
          elsif @sale.items.size <= 0
            notify_warning(:no_items_found)
            redirect_to action: :show, step: :products, id: @sale.id
          end
        end
        t3e @sale.attributes, :client => @sale.client.full_name, :state => @sale.state_label, :label => @sale.label
      end
      # format.json { render :json => @sale, :include => {:items => {:include => :variant}} }
      # format.xml  { render  :xml => @sale, :include => {:invoice_address => {}, :items => {:include => :variant}} }
      # format.pdf  { render  :pdf => @sale, :include => {:items => {:include => :variant}} }
      # format.odt  { render  :odt => @sale, :include => {:items => {:include => :variant}} }
      # format.docx { render :docx => @sale, :include => {:items => {:include => :variant}} }
      # # format.pdf do
      # #   if @sale.invoice?
      # #     render_print_sales_invoice(@sale)
      # #   else
      # #     render_print_sales_order(@sale)
      # #   end
      # # end
    end

  end

  def abort
    return unless @sale = find_and_check
    if request.post?
      @sale.abort
    end
    redirect_to action: :show, id: @sale.id
  end


  list(:creditable_items, model: :sale_items, conditions: ["sale_id=? AND reduced_item_id IS NULL", 'params[:id]'.c]) do |t|
    t.column :label
    t.column :annotation
    t.column :variant
    t.column :price_amount, through: :price, label_method: :amount
    # t.column :quantity
    t.column :credited_quantity, :datatype => :decimal
    t.check_box  :validated, :value => 'true'.c, :label => 'OK'
    t.text_field :quantity, :value => "RECORD.uncredited_quantity".c, :size => 6
  end

  def cancel
    return unless @sale = find_and_check
    session[:sale_id] = @sale.id
    if request.post?
      items = {}
      params[:creditable_items].select{|k,v| v[:validated].to_i == 1}.each do |k, v|
        items[k] = v[:quantity].to_f
      end
      if items.empty?
        notify_error_now(:need_quantities_to_cancel_an_sale)
        return
      end
      responsible = Person.find_by_id(params[:sale][:responsible_id]) if params[:sale]
      credit = @sale.cancel(items, :responsible => responsible || current_user.person)
      if credit.valid?
        redirect_to action: :show, id: credit.id
      else
        raise credit.errors.inspect
      end
    end
    t3e @sale.attributes
  end

  def confirm
    return unless @sale = find_and_check
    if request.post?
      @sale.confirm
    end
    redirect_to action: :show, step: :deliveries, id: @sale.id
  end

  def contacts
    if request.xhr?
      client, address_id = nil, nil
      client = if params[:selected] and address = EntityAddress.find_by_id(params[:selected])
                 address.entity
               else
                 Entity.find_by_id(params[:client_id])
               end
      if client
        session[:current_entity_id] = client.id
        address_id = (address ? address.id : client.default_mail_address.id)
      end
      @sale = Sale.find_by_id(params[:sale_id])||Sale.new(:address_id => address_id, :delivery_address_id => address_id, :invoice_address_id => address_id)
      render :partial => 'addresses_form', :locals => {:client => client, :object => @sale}
    else
      redirect_to action: :index
    end
  end

  def correct
    return unless @sale = find_and_check
    if request.post?
      @sale.correct
    end
    redirect_to action: :show, step: :products, id: @sale.id
  end

  def new
    nature = SaleNature.where(id: params[:nature_id]).first
    nature ||= SaleNature.by_default
    @sale = Sale.new(:nature => nature)
    if client = Entity.find_by_id(params[:client_id]||params[:entity_id]||session[:current_entity_id])
      if client.default_mail_address
        cid = client.default_mail_address.id
        @sale.attributes = {:address_id => cid, :delivery_address_id => cid, :invoice_address_id => cid}
      end
    end
    session[:current_entity_id] = (client ? client.id : nil)
    @sale.responsible_id = current_user.id
    @sale.client_id = session[:current_entity_id]
    @sale.letter_format = false
    @sale.function_title = tg('letter_function_title')
    @sale.introduction = tg('letter_introduction')
    # @sale.conclusion = tg('letter_conclusion')
  end

  def create
    @sale = Sale.new permitted_params
    @sale.number = ''
    return if save_and_redirect(@sale, url: {action: :show, step: :products, id: "id"})
  end

  def edit
    return unless @sale = find_and_check
    unless @sale.draft?
      notify_error(:sale_cannot_be_updated)
      redirect_to action: :show, step: :products, id: @sale.id
      return
    end
    t3e @sale.attributes
    # render_restfully_form
  end

  def update
    return unless @sale = find_and_check
    unless @sale.draft?
      notify_error(:sale_cannot_be_updated)
      redirect_to action: :show, step: :products, id: @sale.id
      return
    end
    if @sale.update_attributes(permitted_params)
      redirect_to action: :show, step: :products, id: @sale.id
      return
    end
    t3e @sale.attributes
    # render_restfully_form
  end

  def destroy
    return unless @sale = find_and_check
    if request.post? or request.delete?
      if @sale.aborted?
        @sale.destroy
      else
        notify_error(:sale_cant_be_deleted)
      end
    end
    redirect_to_current
  end

  def duplicate
    return unless sale = find_and_check
    copy = nil
    begin
      copy = sale.duplicate(:responsible_id => current_user.id)
    rescue Exception => e
      notify_error(:exception_raised, :message => e.message)
    end
    if copy
      redirect_to action: :show, step: :products, id: copy.id
      return
    end
    redirect_to_current
  end

  def invoice
    return unless @sale = find_and_check
    if request.post?
      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless @sale.invoice
        redirect_to action: :show, step: :summary, id: @sale.id
        return
      end
    end
    redirect_to action: :show, step: :products, id: @sale.id
  end

  def propose
    return unless @sale = find_and_check
    if request.post?
      @sale.propose
    end
    redirect_to action: :show, step: :products, id: @sale.id
  end

  def propose_and_invoice
    return unless @sale = find_and_check
    if request.post?
      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless @sale.propose
        raise ActiveRecord::Rollback unless @sale.confirm
        # raise ActiveRecord::Rollback unless @sale.deliver
        raise ActiveRecord::Rollback unless @sale.invoice
      end
    end
    redirect_to action: :show, step: :summary, id: @sale.id
  end

  def refuse
    return unless @sale = find_and_check
    if request.post?
      @sale.refuse
    end
    redirect_to action: :show, step: :products, id: @sale.id
  end


end
