# == Schema Information
# Schema version: 20090407073247
#
# Table name: languages
#
#  id          :integer       not null, primary key
#  name        :string(255)   not null
#  native_name :string(255)   not null
#  iso2        :string(2)     not null
#  iso3        :string(3)     not null
#

class Language < ActiveRecord::Base
  has_many :entities
end
