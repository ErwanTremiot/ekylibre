# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2010 Brice Texier, Thibaud Mérigon
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
# along with this program.  If not, see http://www.gnu.org/licenses.
# 
# == Table: sales_invoices
#
#  accounted_at       :datetime         
#  amount             :decimal(16, 2)   default(0.0), not null
#  amount_with_taxes  :decimal(16, 2)   default(0.0), not null
#  annotation         :text             
#  client_id          :integer          not null
#  company_id         :integer          not null
#  contact_id         :integer          
#  created_at         :datetime         not null
#  created_on         :date             
#  creator_id         :integer          
#  credit             :boolean          not null
#  currency_id        :integer          
#  downpayment_amount :decimal(16, 2)   default(0.0), not null
#  has_downpayment    :boolean          not null
#  id                 :integer          not null, primary key
#  journal_entry_id   :integer          
#  lock_version       :integer          default(0), not null
#  lost               :boolean          not null
#  nature             :string(1)        not null
#  number             :string(64)       not null
#  origin_id          :integer          
#  paid               :boolean          not null
#  payment_delay_id   :integer          not null
#  payment_on         :date             not null
#  sales_order_id     :integer          
#  updated_at         :datetime         not null
#  updater_id         :integer          
#

class SalesInvoice < ActiveRecord::Base
  acts_as_accountable :callbacks=>false
  after_create {|r| r.client.add_event(:sales_invoice, r.updater_id)}
  attr_readonly :company_id
  belongs_to :client, :class_name=>Entity.to_s
  belongs_to :company
  belongs_to :contact
  belongs_to :journal_entry
  belongs_to :origin, :class_name=>SalesInvoice.to_s
  belongs_to :payment_delay, :class_name=>Delay.to_s
  belongs_to :sales_order
  has_many :lines, :class_name=>SalesInvoiceLine.name
  has_many :credits, :class_name=>SalesInvoice.name, :foreign_key=>:origin_id
  has_many :products, :through=>:lines, :uniq=>true

  validates_presence_of :currency_id

  attr_readonly :company_id, :number, :created_on, :sales_order_id, :client_id, :contact_id, :currency_id, :annotation # , :amount, :amount_with_taxes

  def prepare
    self.created_on = Date.today unless self.created_on.is_a? Date
    if self.number.blank?
      last = self.client.sales_invoices.find(:first, :order=>"number desc")
      self.number = (last ? last.number.succ! : '00000001')
    end
    self.company_id = self.sales_order.company_id if self.sales_order

    if self.credit
      self.amount = 0
      self.amount_with_taxes = 0
      for line in self.lines
        self.amount += line.amount
        self.amount_with_taxes += line.amount_with_taxes
      end
    end
    self.currency_id ||= self.sales_order.currency_id if self.sales_order
  end
  
  def prepare_on_create
    self.payment_on ||= self.payment_delay.compute if self.payment_delay
    self.payment_on ||= Date.today
    if self.credit and self.origin
      self.payment_on = Date.today if self.payment_on.nil?
      self.contact_id = self.origin.contact_id
      self.nature = "C"
      self.payment_delay_id = self.origin.payment_delay_id
      self.sales_order_id = self.origin.sales_order_id
      self.currency_id = self.origin.currency_id
    end
  end
  
  def clean_on_create
    specific_numeration = self.company.preference("management.sales_invoices.numeration").value
    if not specific_numeration.nil?
      self.number = specific_numeration.next_value
    end
  end

  def cancel(lines={})
    return false unless lines.keys.size > 0
    credit = SalesInvoice.new(:origin_id=>self.id, :client_id=>self.client_id, :credit=>true, :company_id=>self.company_id)
    ActiveRecord::Base.transaction do
      if saved = credit.save
        for line in self.lines
          if lines[line.id.to_s]
            if lines[line.id.to_s][:validated].to_i == 1
              quantity = 0-lines[line.id.to_s][:quantity].to_f
              if quantity != 0.0
                credit_line = credit.lines.create(:quantity=>quantity, :origin_id=>line.id, :product_id=>line.product_id, :price_id=>line.price_id, :company_id=>line.company_id, :order_line_id=>line.order_line_id)
                unless credit_line.save
                  saved = false
                  credit.errors.add_from_record(credit_line)
                end
              end
            end
          end
        end
      end
      if saved
        if self.company.preference('accountancy.accountize.automatic')
          sales_invoice.to_accountancy if self.company.preference('accountancy.accountize.automatic').value == true
        end
      else
        raise ActiveRecord::Rollback
      end
    end
    return credit
  end
  

  def status
    if not self.creditable? 
      "error"
    elsif self.credited_amount<0
      "warning"
    else 
      ""
    end
  end

  def responsible_name
    if self.sales_order and self.sales_order.responsible
      self.sales_order.responsible.label
    else
      ""
    end
  end

  def label
    tc('label.'+(self.credit ? 'credit' : 'normal'), :number=>self.number, :created_on=>::I18n.localize(self.created_on))
  end

  def product_name
    self.product.name
  end

  def taxes
    self.amount_with_taxes - self.amount
  end

  def address
    a = self.client.full_name+"\n"
    a += (self.contact ? self.contact.address : self.client.default_contact.address).gsub(/\s*\,\s*/, "\n")
    a
  end

  def unpaid_amount
    self.sales_order.sales_invoices.sum(:amount_with_taxes)-self.sales_order.payment_uses.sum(:amount)
  end

  def credited_amount
    self.credits.sum(:amount_with_taxes)
  end

  def creditable?
    not self.credit and self.amount_with_taxes + self.credited_amount > 0
  end

  #this method accountizes the sales_invoice.
  def to_accountancy(action=:create, options={})
    label = tc(:to_accountancy, :resource=>self.class.model_name.human, :number=>self.number, :client=>self.client.full_name, :products=>(self.sales_order.comment.blank? ? self.products.collect{|x| x.name}.to_sentence : self.sales_order.comment), :sales_order=>self.sales_order.number)
    accountize(action, {:journal=>self.company.journal(:sales), :draft_mode=>options[:draft]}) do |entry|
      entry.add_debit(label, self.client.account(:client).id, self.amount_with_taxes)
      for line in self.lines
        entry.add_credit(label, line.product.sales_account_id, line.amount) unless line.quantity.zero?
        entry.add_credit(label, line.price.tax.collected_account_id, line.taxes) unless line.taxes.zero?
      end
    end
  end
  

end
