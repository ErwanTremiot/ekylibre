# encoding: UTF-8
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
# == Table: product_natures
#
#  abilities_list           :text
#  active                   :boolean          not null
#  category_id              :integer          not null
#  created_at               :datetime         not null
#  creator_id               :integer
#  derivative_of            :string(120)
#  derivatives_list         :text
#  description              :text
#  evolvable                :boolean          not null
#  frozen_indicators_list   :text
#  id                       :integer          not null, primary key
#  linkage_points_list      :text
#  lock_version             :integer          default(0), not null
#  name                     :string(255)      not null
#  number                   :string(30)       not null
#  picture_content_type     :string(255)
#  picture_file_name        :string(255)
#  picture_file_size        :integer
#  picture_updated_at       :datetime
#  population_counting      :string(255)      not null
#  reference_name           :string(120)
#  updated_at               :datetime         not null
#  updater_id               :integer
#  variable_indicators_list :text
#  variety                  :string(120)      not null
#


class ProductNature < Ekylibre::Record::Base
  enumerize :variety,       in: Nomen::Varieties.all
  enumerize :derivative_of, in: Nomen::Varieties.all
  enumerize :reference_name, in: Nomen::ProductNatures.all
  # Be careful with the fact that it depends directly on the nomenclature definition
  enumerize :population_counting, in: Nomen::ProductNatures.population_counting.choices, default: Nomen::ProductNatures.population_counting.choices.first, predicates: {prefix: true}
  # enumerize :population_counting, in: Nomen::ProductNatures.attributes[:population_counting].choices, predicates: {prefix: true}, default: Nomen::ProductNatures.attributes[:population_counting].choices.first
  # has_many :available_stocks, class_name: "ProductStock", :conditions => ["quantity > 0"], foreign_key: :product_id
  # has_many :prices, foreign_key: :product_nature_id, class_name: "ProductPriceTemplate"
  belongs_to :category, class_name: "ProductNatureCategory"
  has_many :products, foreign_key: :nature_id, dependent: :restrict_with_exception
  has_many :variants, class_name: "ProductNatureVariant", foreign_key: :nature_id, inverse_of: :nature, dependent: :restrict_with_exception
  has_one :default_variant, -> { order(:id) }, class_name: "ProductNatureVariant", foreign_key: :nature_id

  serialize :abilities_list, SymbolArray
  serialize :derivatives_list, SymbolArray
  serialize :frozen_indicators_list, SymbolArray
  serialize :variable_indicators_list, SymbolArray
  serialize :linkage_points_list, SymbolArray

  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_numericality_of :picture_file_size, allow_nil: true, only_integer: true
  validates_length_of :number, allow_nil: true, maximum: 30
  validates_length_of :derivative_of, :reference_name, :variety, allow_nil: true, maximum: 120
  validates_length_of :name, :picture_content_type, :picture_file_name, :population_counting, allow_nil: true, maximum: 255
  validates_inclusion_of :active, :evolvable, in: [true, false]
  validates_presence_of :category, :name, :number, :population_counting, :variety
  #]VALIDATORS]
  validates_uniqueness_of :number
  validates_uniqueness_of :name

  accepts_nested_attributes_for :variants, :reject_if => :all_blank, :allow_destroy => true
  acts_as_numbered force: false

  delegate :subscribing?, :deliverable?, :purchasable?, to: :category
  delegate :financial_asset_account, :product_account, :charge_account, :stock_account, to: :category

  has_attached_file :picture, {
    :url => '/backend/:class/:id/picture/:style',
    :path => ':rails_root/private/:class/:attachment/:id_partition/:style.:extension',
    :styles => {
      :thumb => ["64x64#", :jpg],
      :identity => ["180x180#", :jpg]
      # :large => ["600x600", :jpg]
    }
  }

  # default_scope -> { order(:name) }
  scope :availables, -> { where(active: true).order(:name) }
  scope :stockables, -> { joins(:category).merge(ProductNatureCategory.stockables).order(:name) }
  scope :saleables,  -> { joins(:category).merge(ProductNatureCategory.saleables).order(:name) }
  scope :purchaseables, -> { joins(:category).merge(ProductNatureCategory.purchaseables).order(:name) }
  # scope :producibles, -> { where(:variety => ["bos", "animal", "plant", "organic_matter"]).order(:name) }

  scope :of_variety, Proc.new { |*varieties|
    where(:variety => varieties.collect{|v| Nomen::Varieties.all(v.to_sym) }.flatten.map(&:to_s).uniq)
  }
  scope :derivative_of, Proc.new { |*varieties|
    where(:derivative_of => varieties.collect{|v| Nomen::Varieties.all(v.to_sym) }.flatten.map(&:to_s).uniq)
  }

  scope :able_to, Proc.new { |type, *abilities|
    query = []
    parameters = []
    for ability in abilities.flatten.join(', ').strip.split(/[[:space:]]*\,[[:space:]]*/)
      if ability =~ /\(.*\)\z/
        params = ability.split(/\s*[\(\,\)]\s*/)
        ability = params.shift.to_sym
        unless item = Nomen::Abilities[ability]
          raise ArgumentError, "Unknown ability: #{ability.inspect}"
        end
        for p in item.parameters
          v = params.shift
          if p == :variety
            unless child = Nomen::Varieties[v]
              raise ArgumentError, "Unknown variety: #{v.inspect}"
            end
            q = []
            for variety in child.self_and_parents
              q << "abilities_list ~ E?"
              parameters << "\\\\m#{ability}\\\\(#{variety.name}\\\\)\\\\Y"
            end
            query << "(" + q.join(" OR ") + ")"
          else
            raise StandardError, "Unknown type of parameter for an ability: #{p.inspect}"
          end
        end
      else
        unless Nomen::Abilities[ability]
          raise ArgumentError, "Unknown ability: #{ability.inspect}"
        end
        query << "abilities_list ~ E?"
        parameters << "\\\\m#{ability}\\\\M"
      end
    end
    where(query.join(" #{type} "), *parameters)
  }

  scope :can, lambda { |*abilities|
    able_to(:or,  *abilities)
  }

  scope :can_each, lambda { |*abilities|
    able_to(:and, *abilities)
  }

  protect(on: :destroy) do
    self.variants.any? or self.products.any?
  end

  before_validation do
    if self.derivative_of
      self.variety ||= self.derivative_of
    end
    self.derivative_of = nil if self.variety.to_s == self.derivative_of.to_s
    # unless self.indicators_array.detect{|i| i.name.to_sym == :population}
    #   self.indicators ||= ""
    #   self.indicators << " population"
    # end
    # self.indicators = self.indicators_array.map(&:name).sort.join(", ")
    # self.abilities_list = self.abilities_list.sort.join(", ")
    return true
  end

  # Returns the closest matching model based on the given variety
  def self.matching_model(variety)
    if item = Nomen::Varieties.find(variety)
      for ancestor in item.self_and_parents
        if model = ancestor.name.camelcase.constantize rescue nil
          return model if model <= Product
        end
      end
    end
    return nil
  end

  # Returns the matching model for the record
  def matching_model
    return self.class.matching_model(self.variety)
  end

  # Returns if population is frozen
  def population_frozen?
    return self.population_counting_unitary?
  end

  # Returns the minimum couting element
  def population_modulo
    return (self.population_counting_decimal? ? 0.0001 : 1)
  end

  # Returns list of all indicators
  def indicators
    return (self.frozen_indicators + self.variable_indicators)
  end

  # Returns list of all indicators names
  def indicators_list
    return (self.frozen_indicators_list + self.variable_indicators_list)
  end

  # Returns list of froezen indicators as an array of indicator items from the nomenclature
  def frozen_indicators
    return self.frozen_indicators_list.collect{ |i| Nomen::Indicators[i] }.compact
  end

  # Returns list of variable indicators as an array of indicator items from the nomenclature
  def variable_indicators
    return self.variable_indicators_list.collect{ |i| Nomen::Indicators[i] }.compact
  end

  # Returns list of indicators as an array of indicator items from the nomenclature
  def indicators_related_to(aspect)
    return self.indicators.select{|i| i.related_to == aspect}
  end

  # Returns whole indicators
  def whole_indicators
    return indicators_related_to(:whole)
  end

  # Returns whole indicator names
  def whole_indicators_list
    return whole_indicators.map{|i| i.name.to_sym }
  end

  # Returns individual indicators
  def individual_indicators
    return indicators_related_to(:individual)
  end

  # Returns individual indicator names
  def individual_indicators_list
    return individual_indicators.map{|i| i.name.to_sym }
  end

  # Returns list of abilities as an array of ability items from the nomenclature
  def abilities
    return self.abilities_list.collect do |i|
      (Nomen::Abilities[i.to_s.split(/\(/).first] ? i.to_s : nil)
    end.compact
  end

  # Returns list of abilities as an array of ability items from the nomenclature
  def linkage_points
    return self.linkage_points_list
  end

  def to
    to = []
    to << :sales if self.saleable?
    to << :purchases if self.purchasable?
    # to << :produce if self.producible?
    to.collect{|x| tc('to.'+x.to_s)}.to_sentence
  end

  # # Returns the default
  # def default_price(options)
  #   price = nil
  #   if template = self.templates.where(:listing_id => listing_id, :active => true, :by_default => true).first
  #     price = template.price
  #   end
  #   return price
  # end

  # def label
  #   tc('label', product_nature: self.name)
  # end

  # def informations
  #   tc('informations.without_components', :product_nature => self.name, :unit => self.unit.label, :size => self.components.size)
  # end

  # Load a product nature from product nature nomenclature
  def self.import_from_nomenclature(reference_name)
    unless item = Nomen::ProductNatures.find(reference_name)
      raise ArgumentError, "The product_nature #{reference_name.inspect} is unknown"
    end
    unless category_item = Nomen::ProductNatureCategories.find(item.category)
      raise ArgumentError, "The category of the product_nature #{item.category.inspect} is unknown"
    end
    unless nature = ProductNature.find_by_reference_name(reference_name)
      attributes = {
        :variety => item.variety,
        :derivative_of => item.derivative_of.to_s,
        :name => item.human_name,
        :population_counting => item.population_counting,
        :category => ProductNatureCategory.import_from_nomenclature(item.category),
        :reference_name => item.name,
        :abilities_list => item.abilities.sort,
        :derivatives_list => (item.derivatives ? item.derivatives.sort : nil),
        :frozen_indicators_list => item.frozen_indicators.sort,
        :variable_indicators_list => item.variable_indicators.sort,
        :active => true
      }
      attributes[:linkage_points_list] = item.linkage_points if item.linkage_points
      nature = self.create!(attributes)
    end
    return nature
  end

  # Load.all product nature from product nature nomenclature
  def self.import_all_from_nomenclature
    for product_nature in Nomen::ProductNatures.all
      import_from_nomenclature(product_nature)
    end
  end

end
