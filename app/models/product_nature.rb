# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Merigon
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
# == Table: product_natures
#
#  active                 :boolean          not null
#  alive                  :boolean          not null
#  asset_account_id       :integer          
#  category_id            :integer          not null
#  charge_account_id      :integer          
#  comment                :text             
#  commercial_description :text             
#  commercial_name        :string(255)      not null
#  created_at             :datetime         not null
#  creator_id             :integer          
#  deliverable            :boolean          not null
#  depreciable            :boolean          not null
#  description            :text             
#  id                     :integer          not null, primary key
#  indivisible            :boolean          not null
#  lock_version           :integer          default(0), not null
#  name                   :string(255)      not null
#  number                 :string(32)       not null
#  producible             :boolean          not null
#  product_account_id     :integer          
#  purchasable            :boolean          not null
#  reductible             :boolean          not null
#  saleable               :boolean          not null
#  storable               :boolean          not null
#  storage                :boolean          not null
#  subscribing            :boolean          not null
#  subscription_duration  :string(255)      
#  subscription_nature_id :integer          
#  towable                :boolean          not null
#  traceable              :boolean          not null
#  tractive               :boolean          not null
#  transferable           :boolean          not null
#  unit_id                :integer          not null
#  updated_at             :datetime         not null
#  updater_id             :integer          
#  variety_id             :integer          not null
#


class ProductNature < CompanyRecord
  attr_accessible :active, :catalog_description, :catalog_name, :category_id, :code, :code2, :comment, :deliverable, :description, :ean13, :for_immobilizations, :for_productions, :for_purchases, :for_sales, :asset_account_id, :name, :nature, :number, :charge_account_id, :reduction_submissive, :product_account_id, :stockable, :subscription_nature_id, :subscription_period, :subscription_quantity, :trackable, :unit_id, :unquantifiable, :weight
  enumerize :nature, :in => [:product, :service, :subscription], :default => :product, :predicates => true
  belongs_to :charge_account, :class_name => "Account"
  belongs_to :product_account, :class_name => "Account"
  belongs_to :subscription_nature
  belongs_to :category, :class_name => "ProductNatureCategory"
  belongs_to :unit
  belongs_to :variety, :class_name => "ProductVariety"
  has_many :available_stocks, :class_name => "ProductStock", :conditions => ["quantity > 0"], :foreign_key => :product_id
  has_many :components, :class_name => "ProductNatureComponent", :conditions => {:active => true}, :foreign_key => :product_id
  has_many :outgoing_delivery_lines, :foreign_key => :product_id
  has_many :prices, :foreign_key => :product_id
  has_many :purchase_lines, :foreign_key => :product_id
  has_many :reservoirs, :conditions => {:reservoir => true}, :foreign_key => :product_id
  has_many :sale_lines, :foreign_key => :product_id
  has_many :stock_moves, :foreign_key => :product_id
  has_many :stock_transfers, :foreign_key => :product_id
  has_many :stocks, :foreign_key => :product_id
  has_many :subscriptions, :foreign_key => :product_id
  has_many :trackings, :foreign_key => :product_id
  has_many :products
  # has_many :warehouses, :through => :stocks
  has_one :default_stock, :class_name => "ProductStock", :order => :name, :foreign_key => :product_id
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :number, :allow_nil => true, :maximum => 32
  validates_length_of :commercial_name, :name, :subscription_duration, :allow_nil => true, :maximum => 255
  validates_inclusion_of :active, :alive, :deliverable, :depreciable, :indivisible, :producible, :purchasable, :reductible, :saleable, :storable, :storage, :subscribing, :towable, :traceable, :tractive, :transferable, :in => [true, false]
  validates_presence_of :category, :commercial_name, :name, :number, :unit, :variety
  #]VALIDATORS]
  validates_presence_of :subscription_nature,   :if => :subscription?
  validates_presence_of :subscription_period,   :if => Proc.new{|u| u.subscription? and u.subscription_nature and u.subscription_nature.period? }
  validates_presence_of :subscription_quantity, :if => Proc.new{|u| u.subscription? and u.subscription_nature and u.subscription_nature.quantity? }
  validates_presence_of :product_account,     :if => :for_sales?
  validates_presence_of :charge_account, :if => :for_purchases?
  validates_uniqueness_of :code
  validates_uniqueness_of :name
  validates_presence_of :weight, :if => :deliverable?

  accepts_nested_attributes_for :stocks, :reject_if => :all_blank, :allow_destroy => true

  default_scope -> { order(:name) }
  scope :availables, -> { where(:active => true).order(:name) }
  scope :stockables, -> { where(:stockable => true).order(:name) }
  scope :purchaseables, -> { where(:for_purchases => true).order(:name) }

  before_validation do
    self.code = self.name.codeize.upper if !self.name.blank? and self.code.blank?
    self.code = self.code[0..7] unless self.code.blank?
    if self.number.blank?
      last = self.class.reorder('number DESC').first
      self.number = last.nil? ? 1 : last.number+1
    end
    while self.class.where("code=? AND id!=?", self.code, self.id||0).first
      self.code.succ!
    end
    self.stockable = false unless self.deliverable?
    self.trackable = false unless self.stockable?
    # self.stockable = true if self.trackable?
    # self.deliverable = true if self.stockable?
    self.for_productions = true if self.has_components?
    self.catalog_name = self.name if self.catalog_name.blank?
    self.subscription_nature_id = nil unless self.subscription?
    return true
  end

  def to
    to = []
    to << :sales if self.for_sales?
    to << :purchases if self.for_purchases?
    to << :produce if self.for_productions?
    to.collect{|x| tc('to.'+x.to_s)}.to_sentence
  end

  def units
    Unit.of_product(self)
  end


  def has_components?
    self.components.count > 0
  end

  def default_price(category_id)
    self.prices.find(:first, :conditions => {:category_id => category_id, :active => true, :by_default => true})
  end

  def label
    tc('label', :product => self["name"], :unit => self.unit["label"])
  end

  def informations
    tc('informations.'+(self.has_components? ? 'with' : 'without')+'_components', :product => self.name, :unit => self.unit.label, :size => self.components.size)
  end

  def duration
    #raise Exception.new self.subscription_nature.nature.inspect+" blabla"
    if self.subscription_nature
      self.send('subscription_'+self.subscription_nature.nature)
    else
      return nil
    end

  end

  def duration=(value)
    #raise Exception.new subscription.inspect+self.subscription_nature_id.inspect
    if self.subscription_nature
      self.send('subscription_'+self.subscription_nature.nature+'=', value)
    end
  end

  def default_start
    # self.subscription_nature.nature == "period" ? Date.today.beginning_of_year : self.subscription_nature.actual_number
    self.subscription_nature.nature == "period" ? Date.today : self.subscription_nature.actual_number
  end

  def default_finish
    period = self.subscription_period || '1 year'
    # self.subscription_nature.nature == "period" ? Date.today.next_year.beginning_of_year.next_month.end_of_month : (self.subscription_nature.actual_number + ((self.subscription_quantity-1)||0))
    self.subscription_nature.nature == "period" ? Delay.compute(period+", 1 day ago", Date.today) : (self.subscription_nature.actual_number + ((self.subscription_quantity-1)||0))
  end

  def default_subscription_label_for(entity)
    return nil unless self.nature == "subscrip"
    entity  = nil unless entity.is_a? Entity
    address = entity.default_contact.address rescue nil
    entity = entity.full_name rescue "???"
    if self.subscription_nature.nature == "period"
      return tc('subscription_label.period', :start => ::I18n.localize(Date.today), :finish => ::I18n.localize(Delay.compute(self.subscription_period.blank? ? '1 year, 1 day ago' : self.product.subscription_period)), :entity => entity, :address => address, :subscription_nature => self.subscription_nature.name)
    elsif self.subscription_nature.nature == "quantity"
      return tc('subscription_label.quantity', :start => self.subscription_nature.actual_number.to_i, :finish => (self.subscription_nature.actual_number.to_i + ((self.subscription_quantity-1)||0)), :entity => entity, :address => address, :subscription_nature => self.subscription_nature.name)
    end
  end

  # Create real stocks moves to update the real state of stocks
  def move_outgoing_stock(options={})
    add_stock_move(options.merge(:virtual => false, :incoming => false))
  end

  def move_incoming_stock(options={})
    add_stock_move(options.merge(:virtual => false, :incoming => true))
  end

  # Create virtual stock moves to reserve the products
  def reserve_outgoing_stock(options={})
    add_stock_move(options.merge(:virtual => true, :incoming => false))
  end

  def reserve_incoming_stock(options={})
    add_stock_move(options.merge(:virtual => true, :incoming => true))
  end

  # Create real stocks moves to update the real state of stocks
  def move_stock(options={})
    add_stock_move(options.merge(:virtual => false))
  end

  # Create virtual stock moves to reserve the products
  def reserve_stock(options={})
    add_stock_move(options.merge(:virtual => true))
  end


  # Generic method to add stock move in product's stock
  def add_stock_move(options={})
    return true unless self.stockable?
    incoming = options.delete(:incoming)
    attributes = options.merge(:generated => true)
    origin = options[:origin]
    if origin.is_a? ActiveRecord::Base
      code = [:number, :code, :name, :id].detect{|x| origin.respond_to? x}
      attributes[:name] = tc('stock_move', :origin => (origin ? ::I18n.t("activerecord.models.#{origin.class.name.underscore}") : "*"), :code => (origin ? origin.send(code) : "*"))
      for attribute in [:quantity, :unit_id, :tracking_id, :warehouse_id, :product_id]
        unless attributes.keys.include? attribute
          attributes[attribute] ||= origin.send(attribute) rescue nil
        end
      end
    end
    attributes[:quantity] = -attributes[:quantity] unless incoming
    attributes[:warehouse_id] ||= self.stocks.first.warehouse_id if self.stocks.size > 0
    attributes[:planned_on] ||= Date.today
    attributes[:moved_on] ||= attributes[:planned_on] unless attributes.keys.include? :moved_on
    self.stock_moves.create!(attributes)
  end


end