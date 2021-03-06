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
# == Table: documents
#
#  archives_count :integer          default(0), not null
#  created_at     :datetime         not null
#  creator_id     :integer
#  id             :integer          not null, primary key
#  key            :string(255)      not null
#  lock_version   :integer          default(0), not null
#  name           :string(255)      not null
#  nature         :string(120)      not null
#  number         :string(60)       not null
#  updated_at     :datetime         not null
#  updater_id     :integer
#

class Document < Ekylibre::Record::Base
  has_many :archives, class_name: "DocumentArchive", dependent: :destroy, inverse_of: :document
  enumerize :nature, in: Nomen::DocumentNatures.all, predicates: {prefix: true}
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :number, allow_nil: true, maximum: 60
  validates_length_of :nature, allow_nil: true, maximum: 120
  validates_length_of :key, :name, allow_nil: true, maximum: 255
  validates_presence_of :key, :name, :nature, :number
  #]VALIDATORS]
  validates_uniqueness_of :key, :scope => :nature
  validates_inclusion_of :nature, in: self.nature.values

  acts_as_numbered

  # Create an archive with the given data
  def archive(data, format, options = {})
    tmp_dir = Rails.root.join('tmp', 'archiving')
    FileUtils.mkdir_p(tmp_dir)
    path = tmp_dir.join("#{self.id}.#{format}")
    File.open(path, "wb:#{data.encoding}") do |f|
      f.write data
    end
    File.open(path, 'rb') do |f|
      self.archives.create!(file: f, template_id: options[:template_id])
    end
    FileUtils.rm_f(path)
  end

  # Returns the matching unique document for the given nature and key
  def self.of(nature, key)
    return self.find_by(nature: nature.to_s, key: key.to_s)
  end

end
