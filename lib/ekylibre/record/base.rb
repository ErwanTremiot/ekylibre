# = Informations
#
# == License
#
# Ekylibre - Simple ERP
# Copyright (C) 2009-2010 Brice Texier, Thibaud Merigon
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


module Ekylibre::Record

  class Scope < Struct.new(:name, :arity)
  end

  class Base < ActiveRecord::Base
    self.abstract_class = true

    # Replaces old module: ActiveRecord::Acts::Tree
    # include ActsAsTree

    # Permits to use enumerize in all models
    extend Enumerize

    # Make all models stampables
    self.stampable

    before_update  :updateable?
    before_destroy :destroyable?

    def destroyable?
      true
    end

    def updateable?
      true
    end
    alias :editable? :updateable?

    # Returns a relation for all other records
    def others
      self.class.where("id != ?", self.id || -1)
    end

    # Returns a relation for the old record in DB
    def old_record
      return nil if self.new_record?
      return self.class.find_by(id: self.id)
    end

    # Returns the definition of custom fields of the object
    def custom_fields
      return self.class.custom_fields
    end

    # Returns the value of given custom_field
    def custom_value(field)
      return self[field.column_name]
    end

    validate :validate_custom_fields

    def validate_custom_fields
      for custom_field in self.custom_fields
        value = self.custom_value(custom_field)
        if value.blank?
          errors.add(custom_field.column_name, :custom_field_is_required, :field => custom_field.name) if custom_field.required?
        else
          if custom_field.text?
            unless custom_field.maximal_length.blank? or custom_field.maximal_length <= 0
              errors.add(custom_field.column_name, :custom_field_is_too_long, :field => custom_field.name, :count => custom_field.maximal_length) if value.length > custom_field.maximal_length
            end
            unless custom_field.minimal_length.blank? or custom_field.minimal_length <= 0
              errors.add(custom_field.column_name, :custom_field_is_too_short, :field => custom_field.name, :count => custom_field.maximal_length) if value.length < custom_field.minimal_length
            end
          elsif custom_field.decimal?
            value = value.to_d unless value.is_a?(Numeric)
            unless custom_field.minimal_value.blank?
              errors.add(custom_field.column_name, :custom_field_is_less_than, :field => custom_field.name, :count => custom_field.minimal_value) if value < custom_field.minimal_value
            end
            unless custom_field.maximal_value.blank?
              errors.add(custom_field.column_name, :custom_field_is_greater_than, :field => custom_field.name, :count => custom_field.maximal_value) if value > custom_field.maximal_value
            end
          end
        end
      end
    end

    # def method_missing(method_name, *args)
    #   # custom fields
    #   if self.customs_fields.find_by(column_name: method_name.to_s)
    #     return self[method_name.to_s]
    #   end
    #   return super
    # end

    @@readonly_counter = 0

    class << self

      # Returns the definition of custom fields of the class
      def custom_fields
        return CustomField.of(self.name)
      end

      def columns_definition
        Ekylibre::Schema.tables[self.table_name] || {}.with_indifferent_access
      end

      def scopes
        @scopes ||= []
      end

      def simple_scopes
        scopes.select{|x| x.arity.zero? }
      end

      def complex_scopes
        scopes.select{|x| !x.arity.zero? }
      end

      # Permits to consider something and something_id like the same
      def scope_with_registration(name, body, &block)
        # Check body.is_a?(Relation) to prevent the relation actually being
        # loaded by respond_to?
        if body.is_a?(::ActiveRecord::Relation) || !body.respond_to?(:call)
          ActiveSupport::Deprecation.warn("Using #scope without passing a callable object is deprecated. For " \
                                          "example `scope :red, where(color: 'red')` should be changed to " \
                                          "`scope :red, -> { where(color: 'red') }`. There are numerous gotchas " \
                                          "in the former usage and it makes the implementation more complicated " \
                                          "and buggy. (If you prefer, you can just define a class method named " \
                                          "`self.red`.)\n" + caller.join("\n")
                                          )
        end
        @scopes ||= []
        arity = body.arity rescue 0
        @scopes << Scope.new(name.to_sym, arity)
        scope_without_registration(name, body, &block)
      end
      alias_method_chain :scope, :registration


      # Permits to consider something and something_id like the same
      def human_attribute_name_with_id(attribute, options = {})
        human_attribute_name_without_id(attribute.to_s.gsub(/_id$/, ''), options)
      end
      alias_method_chain :human_attribute_name, :id

      # Permits to add conditions on attr_readonly
      def attr_readonly_with_conditions(*args)
        options = args.extract_options!
        return attr_readonly_without_conditions(*args) unless options[:if]
        method_name = "readonly_#{@@readonly_counter+=1}?"
        self.send(:define_method, method_name, options[:if])
        code = ""
        code += "before_update do\n"
        code += "  if self.#{method_name}(#{'self' if options[:if].arity>0})\n"
        code += "    old = self.class.find(self.id)\n"
        for attribute in args
          code += "  self['#{attribute}'] = old['#{attribute}']\n"
        end
        code += "  end\n"
        code += "end\n"
        class_eval code
      end
      alias_method_chain :attr_readonly, :conditions

    end




  end

end
