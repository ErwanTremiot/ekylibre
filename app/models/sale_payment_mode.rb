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
# == Table: sale_payment_modes
#
#  cash_id                :integer          
#  commission_account_id  :integer          
#  commission_amount      :decimal(16, 2)   default(0.0), not null
#  commission_percent     :decimal(16, 2)   default(0.0), not null
#  company_id             :integer          not null
#  created_at             :datetime         not null
#  creator_id             :integer          
#  embankables_account_id :integer          
#  id                     :integer          not null, primary key
#  lock_version           :integer          default(0), not null
#  name                   :string(50)       not null
#  published              :boolean          
#  updated_at             :datetime         not null
#  updater_id             :integer          
#  with_accounting        :boolean          not null
#  with_commission        :boolean          not null
#  with_embankment        :boolean          not null
#

class SalePaymentMode < ActiveRecord::Base
  attr_readonly :company_id
  belongs_to :cash
  belongs_to :company
  belongs_to :commission_account, :class_name=>Account.name
  belongs_to :embankables_account, :class_name=>Account.name
  has_many :embankable_payments, :class_name=>SalePayment.name, :foreign_key=>:mode_id, :conditions=>{:embankment_id=>nil}
  has_many :entities, :dependent=>:nullify, :foreign_key=>:payment_mode_id
  has_many :payments, :foreign_key=>:mode_id, :class_name=>SalePayment.name

  validates_presence_of :embankables_account_id, :if=>Proc.new{|x| x.with_embankment? and x.with_accounting? }
  validates_presence_of :cash_id

  def before_validation
    self.embankables_account = nil unless self.with_embankment?
    return true
  end

  def destroyable?
    self.payments.size <= 0
  end  
end