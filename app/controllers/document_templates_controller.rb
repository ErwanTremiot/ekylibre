# -*- coding: utf-8 -*-
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class DocumentTemplatesController < ApplicationController
  manage_restfully :country=>"@current_company.entity.country", :language=>"@current_company.entity.language"

  list(:conditions=>{:company_id=>['@current_company.id']}, :order=>"nature, name") do |t|
    t.column :active
    t.column :name
    t.column :code
    t.column :family_label
    t.column :nature_label
    t.column :by_default
    t.column :to_archive
    t.column :language
    t.column :country
    t.action :print
    t.action :duplicate, :method=>:post
    t.action :edit
    t.action :destroy, :method=>:delete, :confirm=>:are_you_sure_you_want_to_delete, :if=>"RECORD.destroyable\?"
  end

  def duplicate
    return unless @document_template = find_and_check(:document_template)
    if request.post?
      if @document_template 
        attrs = @document_template.attributes.dup
        attrs.delete("id")
        attrs.delete("lock_version")
        attrs.delete_if{|k,v| k.match(/...ate.._../) }
        while @current_company.document_templates.find(:first, :conditions=>{:code=>attrs["code"]})
          attrs["code"].succ!
        end
        DocumentTemplate.create(attrs)
      end
    end
    redirect_to_current    
  end

  def print
    return unless @document_template = find_and_check(:document_template)
    send_data @document_template.sample, :filename=>@document_template.name.simpleize, :type=>Mime::PDF, :disposition=>'inline'
  end

  # Displays the main page with the list of document templates
  def index
  end

  def load
    @current_company.load_prints
    notify(:update_is_done, :success, :now)
    redirect_to :action=>:document_templates
  end

end