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
# == Table: cashes
#
#  account_id           :integer          not null
#  bank_account_key     :string(255)
#  bank_account_number  :string(255)
#  bank_agency_address  :text
#  bank_agency_code     :string(255)
#  bank_code            :string(255)
#  bank_identifier_code :string(11)
#  bank_name            :string(50)
#  country              :string(2)
#  created_at           :datetime         not null
#  creator_id           :integer
#  currency             :string(3)        not null
#  iban                 :string(34)
#  id                   :integer          not null, primary key
#  journal_id           :integer          not null
#  lock_version         :integer          default(0), not null
#  mode                 :string(255)      default("iban"), not null
#  name                 :string(255)      not null
#  nature               :string(20)       default("bank_account"), not null
#  spaced_iban          :string(42)
#  updated_at           :datetime         not null
#  updater_id           :integer
#


require 'test_helper'

class CashTest < ActiveSupport::TestCase
end
