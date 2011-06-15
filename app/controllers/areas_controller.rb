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

class AreasController < ApplicationController
  manage_restfully :district_id=>"@current_company.districts.find(params[:district_id]).id rescue 0", :country=>"@current_company.entity.country"

  list(:conditions=>search_conditions(:areas, :areas=>[:postcode, :name]), :order=>:name) do |t|
    t.column :name
    t.column :postcode
    t.column :city
    t.column :code
    t.column :name, :through=>:district
    t.column :country    
    t.action :edit
    t.action :destroy, :confirm=>:are_you_sure_you_want_to_delete, :method=>:delete
  end

  # Displays the main page with the list of areas
  def index
    session[:area_key] ||= {}
    @key = params[:key] || session[:area_key] 
    @areas = @current_company.areas
    if request.post?
      session[:area_key] = @key
    end
  end

end