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
# == Table: guide_analysis_points
#
#  acceptance_status     :string(255)      not null
#  advice_reference_name :string(255)
#  analysis_id           :integer          not null
#  created_at            :datetime         not null
#  creator_id            :integer
#  id                    :integer          not null, primary key
#  lock_version          :integer          default(0), not null
#  reference_name        :string(255)      not null
#  updated_at            :datetime         not null
#  updater_id            :integer
#
class GuideAnalysisPoint < Ekylibre::Record::Base
  belongs_to :analysis, class_name: "GuideAnalysis", inverse_of: :points
  enumerize :acceptance_status, in: [:passed, :failed, :errored, :passed_with_warnings], predicates: true
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :acceptance_status, :advice_reference_name, :reference_name, allow_nil: true, maximum: 255
  validates_presence_of :acceptance_status, :analysis, :reference_name
  #]VALIDATORS]
  validates_inclusion_of :acceptance_status, in: self.acceptance_status.values

  def status
    {passed: :go, failed: :stop, errored: :stop, passed_with_warnings: :caution}.with_indifferent_access[self.acceptance_status]
  end

end
