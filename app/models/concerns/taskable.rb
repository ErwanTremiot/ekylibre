module Taskable
  extend ActiveSupport::Concern

  included do
    belongs_to :operation
    belongs_to :originator, polymorphic: true
    has_many :product_births,         as: :originator, dependent: :destroy
    has_many :product_deaths,         as: :originator, dependent: :destroy
    has_many :product_divisions,      as: :originator, dependent: :destroy
    has_many :product_enjoyments,     as: :originator, dependent: :destroy
    has_many :product_readings, as: :originator, dependent: :destroy
    has_many :product_linkages,       as: :originator, dependent: :destroy
    has_many :product_localizations,  as: :originator, dependent: :destroy
    has_many :product_reading_tasks,   as: :originator, dependent: :destroy
    has_many :product_memberships,    as: :originator, dependent: :destroy
    has_many :product_mixings,        as: :originator, dependent: :destroy
    has_many :product_ownerships,     as: :originator, dependent: :destroy
    has_one :intervention, through: :operation
  end

end
