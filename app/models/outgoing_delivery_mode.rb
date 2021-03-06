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
# == Table: outgoing_delivery_modes
#
#  code           :string(10)       not null
#  created_at     :datetime         not null
#  creator_id     :integer
#  description    :text
#  id             :integer          not null, primary key
#  lock_version   :integer          default(0), not null
#  name           :string(255)      not null
#  updated_at     :datetime         not null
#  updater_id     :integer
#  with_transport :boolean          not null
#


class OutgoingDeliveryMode < Ekylibre::Record::Base
  has_many :deliveries, foreign_key: :mode_id, class_name: "OutgoingDelivery", inverse_of: :mode
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :code, allow_nil: true, maximum: 10
  validates_length_of :name, allow_nil: true, maximum: 255
  validates_inclusion_of :with_transport, in: [true, false]
  validates_presence_of :code, :name
  #]VALIDATORS]
  validates_uniqueness_of :name, :code

  # Returns default outgoing delivery mode
  def self.by_default
    if delivery = OutgoingDelivery.reorder(id: :desc).first
      return delivery.mode
    else
      return self.order(:name).first
    end
  end
end
