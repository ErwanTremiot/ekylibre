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
# == Table: land_parcels
#
#  area_measure   :decimal(16, 4)   default(0.0), not null
#  area_unit_id   :integer          
#  company_id     :integer          not null
#  created_at     :datetime         not null
#  creator_id     :integer          
#  cultivation_id :integer          
#  description    :text             
#  group_id       :integer          not null
#  id             :integer          not null, primary key
#  lock_version   :integer          default(0), not null
#  master         :boolean          default(TRUE), not null
#  name           :string(255)      not null
#  number         :string(255)      
#  parent_id      :integer          
#  polygon        :string(255)      not null
#  started_on     :date             
#  stopped_on     :date             
#  updated_at     :datetime         not null
#  updater_id     :integer          
#

class LandParcel < ActiveRecord::Base
  acts_as_tree
  attr_readonly :company_id
  belongs_to :area_unit, :class_name=>Unit.name
  belongs_to :company
  belongs_to :group, :class_name=>LandParcelGroup.name
  has_many :operations, :as=>:target
  validates_presence_of :area_unit

  def prepare
    self.master = false if self.master.nil?
    self.polygon ||= "-"
  end

  def divide(subdivisions, divided_on)
    if (total = subdivisions.collect{|s| s[:area_measure].to_f}.sum) != self.area_measure.to_f
      errors.add :area_measure, :invalid, :measure=>total, :expected_measure=>self.area_measure, :unit=>self.area_unit.name
      return false
    end
    return false unless divided_on.is_a? Date
    for subdivision in subdivisions
      child = self.company.land_parcels.create!(subdivision.merge(:started_on=>divided_on, :group_id=>self.group_id, :area_unit_id=>self.area_unit_id))
      self.company.land_parcel_kinships.create!(:parent_land_parcel=>self, :child_land_parcel=>child, :nature=>"divide")
    end
    self.update_attribute(:stopped_on, divided_on)
  end


end