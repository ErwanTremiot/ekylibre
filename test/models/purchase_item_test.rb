# = Informations
#
# == License
#
# Ekylibre - Simple ERP
# Copyright (C) 2009-2012 Brice Texier, Thibaud Merigon
# Copyright (C) 2012-2014 Brice Texier, David Joulin
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
# == Table: purchase_items
#
#  account_id        :integer          not null
#  amount            :decimal(19, 4)   default(0.0), not null
#  annotation        :text
#  created_at        :datetime         not null
#  creator_id        :integer
#  currency          :string(3)        not null
#  id                :integer          not null, primary key
#  indicator_name    :string(120)      not null
#  label             :text
#  lock_version      :integer          default(0), not null
#  position          :integer
#  pretax_amount     :decimal(19, 4)   default(0.0), not null
#  purchase_id       :integer          not null
#  quantity          :decimal(19, 4)   default(1.0), not null
#  tax_id            :integer          not null
#  unit_price_amount :decimal(19, 4)   not null
#  updated_at        :datetime         not null
#  updater_id        :integer
#  variant_id        :integer          not null
#


require 'test_helper'

class PurchaseItemTest < ActiveSupport::TestCase

end
