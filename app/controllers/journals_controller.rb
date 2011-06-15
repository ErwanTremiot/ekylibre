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

class JournalsController < ApplicationController
  manage_restfully :nature=>"params[:nature]||Journal.natures[0][1]"

  @@journal_views = ["lines", "entries", "mixed"]
  cattr_reader :journal_views

  list(:lines, :model=>:journal_entry_lines, :conditions=>journal_entries_conditions, :joins=>:entry, :line_class=>"(RECORD.position==1 ? 'first-line' : '')", :order=>"entry_id DESC, #{JournalEntryLine.table_name}.position") do |t|
    t.column :number, :through=>:entry, :url=>true
    t.column :printed_on, :through=>:entry, :datatype=>:date
    t.column :number, :through=>:account, :url=>true
    t.column :name, :through=>:account, :url=>true
    t.column :name
    t.column :state_label
    t.column :debit
    t.column :credit
  end

  list(:entries, :model=>:journal_entries, :conditions=>journal_entries_conditions, :order=>"created_at DESC") do |t|
    t.column :number, :url=>true
    t.column :printed_on
    t.column :state_label
    t.column :debit
    t.column :credit
    t.action :edit, :if=>'RECORD.updateable? '
    t.action :destroy, :method=>:delete, :confirm=>:are_you_sure_you_want_to_delete, :if=>"RECORD.destroyable\?"
  end

  list(:mixed, :model=>:journal_entries, :conditions=>journal_entries_conditions, :children=>:lines, :order=>"created_at DESC", :per_page=>10) do |t|
    t.column :number, :url=>true, :children=>:name
    t.column :printed_on, :datatype=>:date, :children=>false
    # t.column :label, :through=>:account, :url=>{:action=>:account}
    t.column :state_label
    t.column :debit
    t.column :credit
    t.action :edit, :if=>'RECORD.updateable? '
    t.action :destroy, :method=>:delete, :confirm=>:are_you_sure_you_want_to_delete, :if=>"RECORD.destroyable\?"
  end

  list(:conditions=>{:company_id=>['@current_company.id']}, :order=>:code) do |t|
    t.column :name, :url=>true
    t.column :code, :url=>true
    t.column :nature_label
    t.column :name, :through=>:currency
    t.column :closed_on
    # t.action :document_print, :url=>{:code=>:JOURNAL, :journal=>"RECORD.id"}
    t.action :close, :if=>'RECORD.closable?(Date.today)', :image=>:unlock
    t.action :reopen, :if=>"RECORD.reopenable\?", :image=>:lock
    t.action :edit
    t.action :destroy, :method=>:delete, :confirm=>:are_you_sure_you_want_to_delete
  end

  # Displays details of one journal selected with +params[:id]+
  def show
    return unless @journal = find_and_check(:journal)
    journal_view = @current_user.preference("interface.journal.#{@journal.code}.view")
    journal_view.value = self.journal_views[0] unless self.journal_views.include? journal_view.value
    if view = self.journal_views.detect{|x| params[:view] == x}
      journal_view.value = view
      journal_view.save
    end

    @journal_view = journal_view.value
    t3e @journal.attributes
  end

  def close
    return unless @journal = find_and_check(:journal)
    unless @journal.closable?
      notify(:no_closable_journal)
      redirect_to :action => :journals
      return
    end    
    if request.post?   
      if @journal.close(params[:journal][:closed_on].to_date)
        notify(:journal_closed_on, :success, :closed_on=>::I18n.l(@journal.closed_on), :journal=>@journal.name)
        redirect_to_back 
      end
    end
    t3e @journal.attributes
  end

  def reopen
    return unless @journal = find_and_check(:journal)
    unless @journal.reopenable?
      notify(:no_reopenable_journal)
      redirect_to :action => :journals
      return
    end    
    if request.post?
      if @journal.reopen(params[:journal][:closed_on].to_date)
        notify(:journal_reopened_on, :success, :closed_on=>::I18n.l(@journal.closed_on), :journal=>@journal.name)
        redirect_to_back 
      end
    end
    t3e @journal.attributes    
  end

  # Displays the main page with the list of journals
  def index
  end



  # create_kame(:draft, :model=>:journal_entry_lines, :conditions=>journal_entries_conditions(:with_journals=>true, :state=>:draft), :joins=>"JOIN #{JournalEntry.table_name} ON (entry_id = #{JournalEntry.table_name}.id)", :line_class=>"(RECORD.position==1 ? 'first-line' : '')", :order=>"entry_id DESC, #{JournalEntryLine.table_name}.position") do |t|
  list(:draft_lines, :model=>:journal_entry_lines, :conditions=>journal_entries_conditions(:with_journals=>true, :state=>:draft), :joins=>:entry, :line_class=>"(RECORD.position==1 ? 'first-line' : '')", :order=>"entry_id DESC, #{JournalEntryLine.table_name}.position") do |t|
    t.column :name, :through=>:journal, :url=>true
    t.column :number, :through=>:entry, :url=>true
    t.column :printed_on, :through=>:entry, :datatype=>:date
    t.column :number, :through=>:account, :url=>true
    t.column :name, :through=>:account, :url=>true
    t.column :name
    t.column :debit
    t.column :credit
  end
  
  # this method lists all the entries generated in draft mode.
  def draft
    if request.post? and params[:validate]
      conditions = nil
      begin
        conditions = eval(self.class.journal_entries_conditions(:with_journals=>true, :state=>:draft))
        journal_entries = @current_company.journal_entries.find(:all, :conditions=>conditions)
        undone = 0
        for entry in journal_entries
          entry.confirm if entry.can_confirm?
          undone += 1 if entry.draft?
        end
        notify(:draft_entry_lines_are_validated, :success, :now, :count=>journal_entries.size-undone)
      rescue Exception=>e
        notify(:exception_raised, :error, :now, :message=>e.message)
      end
    end
  end
  

end