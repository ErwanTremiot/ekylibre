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

class Backend::AggregatorsController < BackendController
  # layout false

  respond_to :pdf, :odt, :ods, :docx, :xlsx, :xml, :json, :html, :csv


  def index

  end


  def show
    unless klass = Aggeratio[params[:id]]
      head :not_found
      return
    end
    # raise params.inspect
    @aggregator = klass.new(self, params)
    t3e :name => klass.human_name
    respond_with @aggregator
  end


end
