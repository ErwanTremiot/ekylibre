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
# == Table: product_nature_categories
#
#  active                     :boolean          not null
#  charge_account_id          :integer
#  created_at                 :datetime         not null
#  creator_id                 :integer
#  depreciable                :boolean          not null
#  description                :text
#  financial_asset_account_id :integer
#  id                         :integer          not null, primary key
#  lock_version               :integer          default(0), not null
#  name                       :string(255)      not null
#  number                     :string(30)       not null
#  pictogram                  :string(120)
#  product_account_id         :integer
#  purchasable                :boolean          not null
#  reductible                 :boolean          not null
#  reference_name             :string(255)
#  saleable                   :boolean          not null
#  stock_account_id           :integer
#  storable                   :boolean          not null
#  subscribing                :boolean          not null
#  subscription_duration      :string(255)
#  subscription_nature_id     :integer
#  updated_at                 :datetime         not null
#  updater_id                 :integer
#
require 'test_helper'

class ProductNatureCategoryTest < ActiveSupport::TestCase

  test "presence of fixtures" do
    # assert_equal 2, ProductNatureCategory.count
  end

end
