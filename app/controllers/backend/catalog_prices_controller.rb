# coding: utf-8
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2013 David Joulin, Brice Texier
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

class Backend::CatalogPricesController < BackendController
  manage_restfully

  unroll

  list do |t|
    t.column :variant, url: true
    t.column :amount
    t.column :started_at
    t.column :stopped_at
    t.column :reference_tax, url: true
    t.column :all_taxes_included
    t.column :catalog, url: true
    t.action :edit
    t.action :destroy, if: :destroyable?
  end

end
