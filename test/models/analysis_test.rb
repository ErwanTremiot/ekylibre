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
# == Table: analyses
#
#  analysed_at      :datetime
#  analyser_id      :integer
#  created_at       :datetime         not null
#  creator_id       :integer
#  description      :text
#  geolocation      :spatial({:srid=>
#  id               :integer          not null, primary key
#  lock_version     :integer          default(0), not null
#  nature           :string(255)      not null
#  number           :string(255)      not null
#  product_id       :integer
#  reference_number :string(255)
#  sampled_at       :datetime         not null
#  sampler_id       :integer
#  updated_at       :datetime         not null
#  updater_id       :integer
#
require 'test_helper'

class AnalysisTest < ActiveSupport::TestCase

  test "presence of fixtures" do
    # assert_equal 2, Analysis.count
  end

end
