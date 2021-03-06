# encoding: utf-8
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2009-2012 Brice Texier
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

class BackendController < BaseController
  protect_from_forgery

  before_filter :authenticate_user!
  before_filter :configure_versioner
  before_filter :themize

  layout :dialog_or_not

  include Userstamp
  # include ExceptionNotifiable
  # local_addresses.clear


  # Create unroll action for all scopes in the model corresponding to the controller
  # including the default scope
  def self.unroll(options = {})
    model = (options.delete(:model) || controller_name).to_s.classify.constantize
    foreign_record  = model.name.underscore
    foreign_records = foreign_record.pluralize
    scope_name = options.delete(:scope) || name
    max = options[:max] || 80
    available_methods = model.columns_definition.keys.map(&:to_sym)
    if label = options.delete(:label)
      label = (label.is_a?(Symbol) ? "{#{label}:%X%}" : label.to_s)
    else
      # base = "unroll." + self.controller_path
      # label = I18n.translate(base + ".#{name || :all}", :default => [(base + ".all").to_sym, ""])
      label = I18n.translate("unroll." + self.controller_path, :default => "")
      if label.blank?
        label = '{' + [:title, :label, :full_name, :name, :code, :number].select{|x| available_methods.include?(x)}.first.to_s + ':%X%}'
      end
    end

    unless order = options[:order]
      order = [:title, :label, :full_name, :name, :code, :number].detect{|x| available_methods.include?(x)}
      order ||= :id
    end

    columns = []
    item_label = label.inspect.gsub(/\{\!?[a-z\_\.]+(\:\%?X\%?)?\}/) do |word|
      ca = word[1..-2].split(":")
      name = ca.first
      i = nil
      if name =~ /\A\!/
        i = "item." + name.gsub!(/\A\!/, '')
      else
        if name =~ /\./
          i = "item.#{name}"
          array = name.split(/\./)
          fmodel = model
          for step in array[0..-2]
            fmodel = fmodel.reflections[step.to_sym].class_name.constantize
          end
          columns << {name: name.gsub(/\W/, '_'), search: fmodel.table_name + "." + array[-1], filter: ca.second || "X%"}
        elsif column = model.columns_definition[name]
          i = "item.#{name}"
          columns << column.options.merge(search: "#{model.table_name}.#{name}", filter: ca.second || "X%")
        else
          raise StandardError, "Cannot handle #{name} for #{model.name}"
        end
      end
      steps = i.to_s.split('.')
      expr = (0..(steps.size - 1)).to_a.collect do |s|
        steps[0..s].join(".")
      end
      "\" + ((#{expr.join(' and ')}) ? #{i}.l : '') + \""
    end
    item_label.gsub!(/\A\"\"\s*\+\s*/, '')
    item_label.gsub!(/\s*\+\s*\"\"\z/, '')

    fill_in = (options.has_key?(:fill_in) ? options[:fill_in] : columns.size == 1 ? columns.first[:name] : model.columns_definition["name"] ? :name : nil)
    fill_in = fill_in.to_sym unless fill_in.nil?

    if !fill_in.nil? and !columns.detect{|c| c[:name] == fill_in }
      raise StandardError.new("Label (#{label}, #{columns.inspect}) of unroll must include the primary column: #{fill_in.inspect}")
    end

    haml  = ""
    haml << "- if items.any?\n"
    haml << "  %ul.items-list\n"
    haml << "    - for item in items.limit(items.count > #{(max*1.5).round} ? #{max} : #{max*2})\n"
    haml << "      %li.item{'data-item-label' => #{item_label}, 'data-item-id' => item.id}\n"
    if options[:partial]
      haml << "        = render '#{partial}', :item => item\n"
    else
      haml << "        = highlight(#{item_label}, keys)\n"
    end
    haml << "  - if items.count > #{(max*1.5).round}\n"
    haml << "    %span.items-status.items-status-too-many-records\n"
    haml << "      = I18n.t('labels.x_items_remain_on_y', :count => (items.count - #{max}))\n"
    haml << "- else\n"
    haml << "  %ul.items-list\n"
    unless fill_in.nil?
      haml << "    - unless search.blank?\n"
      haml << "      %li.item.special{'data-new-item' => search, 'data-new-item-parameter' => '#{fill_in}'}= I18n.t('labels.add_x', :x => content_tag(:strong, search)).html_safe\n"
    end
    haml << "    %li.item.special{'data-new-item' => ''}= I18n.t('labels.add_#{model.name.underscore}', :default => [:'labels.add_new_record'])\n"
    # haml << "  %span.items-status.items-status-empty\n"
    # haml << "    =I18n.t('labels.no_results')\n"

    # Write haml in cache
    path = self.controller_path.split('/')
    path[-1] << ".html.haml"
    view = Rails.root.join("tmp", "cache", "unroll", *path)
    FileUtils.mkdir_p(view.dirname)
    File.open(view, "wb") do |f|
      f.write(haml)
    end

    code  = "def unroll\n"
    code << "  conditions = []\n"

    code << "  klass = controller_name.classify.constantize\n"
    code << "  items = klass.unscoped"
    if options[:includes]
      code << ".includes(#{options[:includes].inspect})"
      code << ".references(#{options[:includes].inspect})"
    end
    code <<  ".order(#{order.inspect})\n"
    # code << "  items = #{model.name}.unscoped\n"
    # code << "  raise params[:scope].inspect\n"
    code << "  if scopes = params[:scope]\n"
    code << "    scopes = {scopes.to_sym => true} if scopes.is_a?(String)\n"
    code << "    for scope, parameters in scopes.symbolize_keys\n"
    code << "      if (parameters.is_a?(TrueClass) or parameters == 'true') and klass.simple_scopes.map(&:name).include?(scope)\n"
    code << "        items = items.send(scope)\n"
    code << "      elsif parameters.is_a?(String) and klass.complex_scopes.map(&:name).include?(scope)\n"
    code << "        items = items.send(scope, *(parameters.strip.split(/\s*\,\s*/)))\n"
    code << "      else\n"
    code << "        logger.error(\"Scope \#{scope.inspect} is unknown for \#{klass.name}. \#{klass.scopes.map(&:name).inspect} are expected.\")\n"
    code << "        head :bad_request\n"
    code << "        return false\n"
    code << "      end\n"
    code << "    end\n"
    code << "  end\n"

    code << "  keys = params[:q].to_s.strip.mb_chars.downcase.normalize.split(/[\\s\\,]+/)\n"
    code << "  if params[:id]\n"
    code << "    items = items.where(id: params[:id])\n"
    searchable_columns = columns.delete_if{ |c| c[:type] == :boolean }
    if searchable_columns.size > 0
      code << "  elsif keys.size > 0\n"
      code << "    conditions = ['(']\n"
      code << "    keys.each_with_index do |key, index|\n"
      code << "      conditions[0] << ') AND (' if index > 0\n"
      code << "      conditions[0] << " + searchable_columns.collect do |column|
        "LOWER(CAST(#{column[:search]} AS VARCHAR)) ~ E?"
      end.join(' OR ').inspect + "\n"
      code << "      conditions += [" + searchable_columns.collect do |column|
        column[:filter].inspect.gsub('X', '" + key + "').gsub('%', '')
          .gsub(/(^\"\"\s*\+\s*|\s*\+\s*\"\"\s*\+\s*|\s*\+\s*\"\"$)/, '')
      end.join(", ") + "]\n"
      code << "    end\n"
      code << "    conditions[0] << ')'\n"
      code << "    items = items.where(conditions)\n"
    else
      logger.error("No searchable columns for #{self.controller_path}#unroll")
    end
    code << "  end\n"

    code << "  respond_to do |format|\n"
    code << "    format.html { render file: '#{view.relative_path_from(Rails.root)}', :locals => { items: items, keys: keys, search: params[:q].to_s.capitalize.strip }, layout: false }\n"
    code << "    format.json { render json: items.collect{|item| {label: #{item_label}, id: item.id}} }\n"
    code << "    format.xml  { render  xml: items.collect{|item| {label: #{item_label}, id: item.id}} }\n"
    code << "  end\n"
    code << "end"
    # code.split("\n").each_with_index{|l, x| puts((x+1).to_s.rjust(4)+": "+l)}
    class_eval(code)
    return :unroll
  end


  protected

  # Overrides respond_with method in order to use specific parameters for reports
  # Adds :with and :key, :name parameters
  def respond_with_with_template(*resources, &block)
    resources << {} unless resources.last.is_a?(Hash)
    resources[-1][:with] = (params[:template].to_s.match(/^\d+$/) ? params[:template].to_i : params[:template].to_s) if params[:template]
    for param in [:key, :name]
      resources[-1][param] = params[param] if params[param]
    end
    respond_with_without_template(*resources, &block)
  end

  hide_action :respond_with, :respond_with_without_template
  alias_method_chain :respond_with, :template

  # def render_restfully_form(options = {})
  #   # operation = self.action_name.to_sym
  #   # operation = (operation == :create ? :new : operation == :update ? :edit : operation)
  #   # partial   = options[:partial] || 'form'
  #   # options[:form_options] = {} unless options[:form_options].is_a?(Hash)
  #   # options[:form_options][:multipart] = true if options[:multipart]
  #   # render(:template => options[:template]||"forms/#{operation}", :locals => {:operation => operation, :partial => partial, :options => options})
  #   render(:template  => "forms/#{self.action_name}", :locals => {:options => options})
  # end


  # Find a record with the current environment or given parameters and check availability of it
  def find_and_check(model = nil, id = nil)
    model ||= self.controller_name
    id    ||= params[:id]
    begin
      return model.to_s.classify.constantize.find(id)
    rescue
      notify_error(:unavailable_model, :model => model.inspect, :id => id)
      redirect_to_current
      return false
    end
  end

  def save_and_redirect(record, options={}, &block)
    url = options[:url] || :back
    record.attributes = options[:attributes] if options[:attributes]
    ActiveRecord::Base.transaction do
      if record.send(:save) or options[:saved]
        yield record if block_given?
        response.headers["X-Return-Code"] = "success"
        response.headers["X-Saved-Record-Id"] = record.id.to_s
        if params[:dialog]
          head :ok
        else
          # TODO: notify if success
          if url == :back
            redirect_to_back
          else
            record.reload
            if url.is_a? Hash
              url0 = {}
              url.each{|k,v| url0[k] = (v.is_a?(String) ? record.send(v) : v)}
              url = url0
            end
            redirect_to(url)
          end
        end
        return true
      end
    end
    response.headers["X-Return-Code"] = "invalid"
    return false
  end

  # For title I18n : t3e :)
  def t3e(*args)
    @title ||= {}
    for arg in args
      arg = arg.attributes if arg.respond_to?(:attributes)
      raise ArgumentError.new("Hash expected, got #{arg.class.name}:#{arg.inspect}") unless arg.is_a? Hash
      arg.each do |k,v|
        @title[k.to_sym] = if v.respond_to?(:strftime) or v.is_a?(Numeric)
                             ::I18n.localize(v)
                           else
                             v.to_s
                           end
      end
    end
  end

  private

  def dialog_or_not()
    return (request.xhr? ? "popover" : params[:dialog] ? "dialog" : "backend")
  end


  # Set HTTP headers to block page caching
  def no_cache()
    # Change headers to force zero cache
    response.headers["Last-Modified"] = Time.now.httpdate
    response.headers["Expires"] = '0'
    # HTTP 1.0
    response.headers["Pragma"] = "no-cache"
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
  end

  # # Load current user
  # def identify()
  #   # Load current_user if connected
  #   @current_user = nil
  #   @current_user = User.find_by(id: session[:user_id]).readonly if session[:user_id]
  # end

  def configure_versioner
    Version.current_user = current_user
  end

  def themize()
    # TODO: Dynamic theme choosing
    if current_user
      if %w(margarita tekyla tekyla-sunrise).include?(params[:theme])
        current_user.prefer!("theme", params[:theme])
      end
      @current_theme = current_user.preference("theme", "tekyla").value
    else
      @current_theme = "tekyla"
    end
  end


  # Controls access to every view in Ekylibre.
  def authorize()
    # Get action rights
    controller_rights = {} unless controller_rights = User.rights[self.controller_name.to_sym]
    action_rights = controller_rights[self.action_name.to_sym]||[]

    # Search help article
    @article = "#{self.controller_path}-#{self.action_name}" # search_article

    # Returns if action is public
    return true if action_rights.include?(:__public__)

    # Check current_user
    unless current_user
      notify_error(:access_denied, :reason => "NOT PUBLIC", :url => request.url.inspect)
      redirect_to_login(request.url)
      return false
    end

    # # Set session variables and check state
    # session[:last_page] ||= {}
    # if request.get? and not request.xhr? and not [:sessions, :help].include?(self.controller_name.to_sym)
    #   session[:last_url] = request.path
    # end

    # # Check expiration
    # if !session[:last_query].is_a?(Integer)
    #   redirect_to_login(request.path)
    #   return false
    # elsif session[:last_query].to_i<Time.now.to_i-session[:expiration].to_i
    #   notify(:expired_session)
    #   if request.xhr?
    #     render :text => "<script>window.location.replace('#{new_session_url}')</script>"
    #   else
    #     redirect_to_login(request.path)
    #   end
    #   return false
    # else
    #   session[:last_query] = Time.now.to_i
    # end

    # Check access for registered actions
    return true if action_rights.include?(:__minimum__)

    # Check rights before allowing access
    if message = @current_user.authorization(self.controller_name, self.action_name, session[:rights])
      if @current_user.admin
        notify_error_now(:access_denied, :reason => message, :url => request.path.inspect)
      else
        notify_error(:access_denied, :reason => message, :url => request.path.inspect)
        redirect_to_back
        return false
      end
    end

    # Returns true if authorized
    return true
  end





  # # Fill the history array
  # def historize()
  #   if @current_user and request.get? and not request.xhr? and params[:format].blank?
  #     session[:history] = [] unless session[:history].is_a? Array
  #     session[:history].delete_if { |h| h[:path] == request.path }
  #     session[:history].insert(0, {:title => self.human_action_name, :path => request.path}) # :url => request.url, :reverse => Ekylibre.menu.page(self.controller_name, self.action_name)
  #     session[:history].delete_at(30)
  #   end
  # end



  def search_article(article = nil)
    # session[:help_history] = [] unless session[:help_history].is_a? [].class
    article ||= "#{self.controller_path}-#{self.action_name}"
    file = nil
    for locale in [I18n.locale, I18n.default_locale]
      for f, attrs in Ekylibre.helps
        next if attrs[:locale].to_s != locale.to_s
        file_name = [article, article.split("-")[0] + "-index"].detect{|name| attrs[:name] == name}
        file = f and break unless file_name.blank?
      end
      break unless file.nil?
    end
    # if file and session[:side] and article != session[:help_history].last
    #   session[:help_history] << file
    # end
    file ||= article.to_sym
    return file
  end

  def redirect_to_login(url = nil)
    raise "Why?"
    reset_session
    @current_user = nil
    redirect_to(new_user_session_url(:redirect => url))
  end

  def redirect_to_back(options={})
    if !params[:redirect].blank?
      redirect_to params[:redirect], options
      # elsif session[:history].is_a?(Array) and session[:history].second.is_a?(Hash)
      #   session[:history].delete_at(0) unless options[:direct]
      #   redirect_to session[:history][0][:path], options
    elsif request.referer and request.referer != request.path
      redirect_to request.referer, options
    else
      redirect_to(root_url)
    end
  end

  def redirect_to_current(options={})
    redirect_to_back(options.merge(:direct => true))
  end

  # Autocomplete helper
  def self.autocomplete_for(column, options = {})
    model = (options.delete(:model) || controller_name).to_s.classify.constantize
    item =  model.name.underscore.to_s
    items = item.pluralize
    items = "many_#{items}" if items == item
    code =  "def #{__method__}_#{column}\n"
    code << "  if params[:term]\n"
    code << "    pattern = '%'+params[:term].to_s.mb_chars.downcase.strip.gsub(/\s+/,'%').gsub(/[#{String::MINUSCULES.join}]/,'_')+'%'\n"
    code << "    @#{items} = #{model.name}.select('DISTINCT #{column}').where('LOWER(#{column}) LIKE ?', pattern).order('#{column} ASC').limit(80)\n"
    code << "    respond_to do |format|\n"
    code << "      format.html { render :inline => \"<%=content_tag(:ul, @#{items}.map { |#{item}| content_tag(:li, #{item}.#{column})) }.join.html_safe)%>\" }\n"
    code << "      format.json { render :json => @#{items}.collect{|#{item}| #{item}.#{column}}.to_json }\n"
    code << "    end\n"
    code << "  else\n"
    code << "    render :text => '', :layout => true\n"
    code << "  end\n"
    code << "end\n"
    class_eval(code, "#{__FILE__}:#{__LINE__}")
  end


  # Build standard RESTful actions to manage records of a model
  def self.manage_restfully(defaults = {})
    name = self.controller_name
    options = defaults.extract!(:t3e, :redirect_to, :xhr, :destroy_to, :subclass_inheritance, :partial, :multipart, :except, :only)
    url  = options[:redirect_to]
    durl = options[:destroy_to]
    actions = [:index, :show, :new, :create, :edit, :update, :destroy]
    actions &= [options[:only]].flatten if options[:only]
    actions -= [options[:except]].flatten if options[:except]

    record_name = name.to_s.singularize
    model_name  = name.to_s.classify
    model = model_name.constantize

    aname = self.controller_path.underscore
    base_url = aname.gsub(/\//, "_")

    # url = base_url.singularize + "_url(@#{record_name})" if url.blank?

    if url.blank?
      named_url = base_url.singularize + "_url"
      if instance_methods(true).include?(:show)
        url = "{:controller => :'#{aname}', :action => :show, :id => 'id'}"
      else
        named_url = base_url + "_url"
        url = named_url if instance_methods(true).include?(named_url.to_sym)
      end
    elsif url.is_a?(Code)
      url.gsub!(/RECORD/, '@' + record_name)
    end


    render_form_options = []
    render_form_options << "partial: '#{options[:partial]}'" if options[:partial]
    render_form_options << "multipart: true" if options[:multipart]
    render_form = "render(" + render_form_options.join(", ") + ")"

    t3e_code = "t3e(@#{record_name}.attributes"
    if t3e = options[:t3e]
      t3e_code << ".merge(" + t3e.collect{|k,v|
        "#{k}: (" + (v.is_a?(Symbol) ? "@#{record_name}.#{v}" : v.inspect.gsub(/RECORD/, '@' + record_name)) + ")"
      }.join(", ") + ")"
    end
    t3e_code << ")"

    code = ''

    code << "respond_to :html, :xml, :json\n"
    # code << "respond_to :pdf, :odt, :ods, :csv, :docx, :xlsx, :only => [:show, :index]\n"

    if actions.include?(:index)
      code << "def index\n"
      code << "  respond_to do |format|\n"
      code << "    format.html\n"
      code << "    format.xml  { render xml:  resource_model.all }\n"
      code << "    format.json { render json: resource_model.all }\n"
      code << "  end\n"
      code << "end\n"
    end

    if actions.include?(:show)
      code << "def show\n"
      code << "  return unless @#{record_name} = find_and_check(:#{name})\n"
      if options[:subclass_inheritance]
        code << "  if @#{record_name}.type and @#{record_name}.type != '#{model_name}'\n"
        code << "    redirect_to controller: @#{record_name}.type.tableize, action: :show, id: @#{record_name}.id\n"
        code << "    return\n"
        code << "  end\n"
      end
      code << "  respond_to do |format|\n"
      code << "    format.html { #{t3e_code} }\n"
      code << "    format.xml  { render xml:  @#{record_name} }\n"
      code << "    format.json { render json: @#{record_name} }\n"
      code << "  end\n"
      code << "end\n"
    end

    code << "def resource_model\n"
    code << "  #{model_name}\n"
    code << "end\n"
    code << "private :resource_model\n"

    code << "def permitted_params\n"
    code << "  params.require(:#{record_name}).permit!\n"
    # code << "  params.require(controller_name.singularize).permit!\n"
    code << "end\n"
    code << "private :permitted_params\n"

    if options[:subclass_inheritance]
      if self != BackendController
        code << "def self.inherited(subclass)\n"
        # TODO inherit from superclass parammeters (superclass.manage_restfully_options)
        code << "  subclass.manage_restfully(#{options.inspect})\n"
        code << "end\n"
      end
    end

    if actions.include?(:new)
      code << "def new\n"
      # values = model.accessible_attributes.to_a.inject({}) do |hash, attr|
      columns = model.columns_hash.keys
      columns = columns.delete_if{|c| [:depth, :rgt, :lft, :id, :lock_version, :updated_at, :updater_id, :creator_id, :created_at].include?(c.to_sym) }
      values = columns.inject({}) do |hash, attr|
        hash[attr] = "params[:#{attr}]".c unless attr.blank? or attr.to_s.match(/_attributes$/)
        hash
      end.merge(defaults).collect{|k,v| "#{k}: (#{v.inspect})"}.join(", ")
      code << "  @#{record_name} = resource_model.new(#{values})\n"
      # code << "  @#{record_name} = resource_model.new(permitted_params)\n"
      if xhr = options[:xhr]
        code << "  if request.xhr?\n"
        code << "    render partial: #{xhr.is_a?(String) ? xhr.inspect : 'detail_form'.inspect}\n"
        code << "  else\n"
        code << "    #{render_form}\n"
        code << "  end\n"
      else
        code << "  #{render_form}\n"
      end
      code << "end\n"
    end

    if actions.include?(:create)
      code << "def create\n"
      code << "  @#{record_name} = resource_model.new(permitted_params)\n"
      code << "  return if save_and_redirect(@#{record_name}#{', url: (' + url + ')' if url})\n"
      code << "  #{render_form}\n"
      code << "end\n"
    end

    if actions.include?(:edit)
      code << "def edit\n"
      code << "  return unless @#{record_name} = find_and_check(:#{name})\n"
      code << "  #{t3e_code}\n"
      code << "  #{render_form}\n"
      code << "end\n"
    end

    if actions.include?(:update)
      code << "def update\n"
      code << "  return unless @#{record_name} = find_and_check(:#{name})\n"
      code << "  #{t3e_code}\n"
      code << "  @#{record_name}.attributes = permitted_params\n"
      code << "  return if save_and_redirect(@#{record_name}#{', url: (' + url + ')' if url})\n"
      code << "  #{render_form}\n"
      code << "end\n"
    end

    if actions.include?(:destroy)
      # this action deletes or hides an existing record.
      code << "def destroy\n"
      code << "  return unless @#{record_name} = find_and_check(:#{name})\n"
      if model.instance_methods.include?(:destroyable?)
        code << "  if @#{record_name}.destroyable?\n"
        # code << "    resource_model.destroy(@#{record_name}.id)\n"
        code << "    @#{record_name}.destroy\n"
        code << "    notify_success(:record_has_been_correctly_removed)\n"
        code << "  else\n"
        code << "    notify_error(:record_cannot_be_removed)\n"
        code << "  end\n"
      else
        code << "  resource_model.destroy(@#{record_name}.id)\n"
        code << "  notify_success(:record_has_been_correctly_removed)\n"
      end
      # code << "  redirect_to #{durl ? durl : model.name.underscore.pluralize+'_url'}\n"
      code << "  " + (durl ? 'redirect_to(' + durl.inspect.gsub(/RECORD/, "@#{record_name}") + ')' : 'redirect_to_current') + "\n"
      code << "end\n"
    end

    # code.split("\n").each_with_index{|l, x| puts((x+1).to_s.rjust(4)+": "+l)}
    unless Rails.env.production?
      file = Rails.root.join("tmp", "code", "manage_restfully", "#{controller_path}.rb")
      FileUtils.mkdir_p(file.dirname)
      File.open(file, "wb") do |f|
        f.write code
      end
    end

    class_eval(code)
  end


  # Build standard actions to manage records of a model
  def self.manage_restfully_list(order_by=:id)
    name = self.controller_name
    record_name = name.to_s.singularize
    model = name.to_s.singularize.classify.constantize
    records = model.name.underscore.pluralize
    raise ArgumentError.new("Unknown column for #{model.name}") unless model.columns_definition[order_by]
    code = ''

    sort = ""
    position, conditions = "#{record_name}_position_column", "#{record_name}_conditions"
    sort << "#{position}, #{conditions} = #{record_name}.position_column, #{record_name}.scope_condition\n"
    sort << "#{records} = #{model.name}.where(#{conditions}).order(#{position}+', #{order_by}')\n"
    sort << "#{records}_count = #{records}.count(#{position})\n"
    sort << "unless #{records}_count == #{records}.uniq.count(#{position}) and #{records}.sum(#{position}) == #{records}_count*(#{records}_count+1)/2\n"
    sort << "  #{records}.each_with_index do |#{record_name}, i|\n"
    sort << "    #{model.name}.where(:id => #{record_name}.id).update_all(#{position} => i+1)\n"
    sort << "  end\n"
    sort << "end\n"

    code << "def up\n"
    code << "  return unless #{record_name} = find_and_check(:#{name})\n"
    code << "  #{record_name}.move_higher\n"
    code << sort.gsub(/^/, "  ")
    code << "  redirect_to_current\n"
    code << "end\n"

    code << "def down\n"
    code << "  return unless #{record_name} = find_and_check(:#{name})\n"
    code << "  #{record_name}.move_lower\n"
    code << sort.gsub(/^/, "  ")
    code << "  redirect_to_current\n"
    code << "end\n"

    # list = code.split("\n"); list.each_index{|x| puts((x+1).to_s.rjust(4)+": "+list[x])}
    class_eval(code)
  end

  #
  def self.manage_restfully_picture()
    name = self.controller_name
    record_name = name.to_s.singularize
    code = ''
    code << "def picture\n"
    code << "  return unless #{record_name} = find_and_check(:#{name})\n"
    code << "  if #{record_name}.picture.file?\n"
    code << "    send_file(#{record_name}.picture.path(params[:style] || :original))\n"
    code << "  else\n"
    code << "    head :not_found\n"
    code << "  end\n"
    code << "end\n"
    class_eval(code)
  end

  def self.deprecated_search_conditions(model_name, columns)
    ActiveSupport::Deprecation.warn("Use search_conditions instead of deprecated_search_conditions")
    model = model_name.to_s.classify.constantize
    columns = [columns] if [String, Symbol].include? columns.class
    columns = columns.collect{|k,v| v.collect{|x| "#{k}.#{x}"}} if columns.is_a? Hash
    columns.flatten!
    raise ArgumentError.new("Bad columns: "+columns.inspect) unless columns.is_a? Array
    code = ""
    code << "c = ['1=1']\n"
    code << "session[:#{model.name.underscore}_key].to_s.lower.split(/\\s+/).each{|kw| kw='%'+kw+'%';"
    code << "c[0] << ' AND ("+columns.collect{|x| 'LOWER(CAST('+x.to_s+' AS VARCHAR)) LIKE ?'}.join(' OR ')+")';\n"
    code << "c += [#{(['kw']*columns.size).join(',')}]"
    code << "}\n"
    code << "c"
    code.c
  end

  # search is a hash like {table: [columns...]}
  def self.search_conditions(search = {}, options={})
    conditions = options[:conditions] || 'c'
    options[:except]  ||= []
    options[:filters] ||= {}
    variable ||= options[:variable] || "params[:q]"
    tables = search.keys.select{|t| !options[:except].include? t}
    code = "\n#{conditions} = ['1=1']\n"
    columns = search.collect do |table, filtered_columns|
      filtered_columns.collect do |column|
        ActiveRecord::Base.connection.quote_table_name(table.is_a?(Symbol) ? table.to_s.classify.constantize.table_name : table) +
          "." +
          ActiveRecord::Base.connection.quote_column_name(column)
      end
    end.flatten
    code << "for kw in #{variable}.to_s.lower.split(/\\s+/)\n"
    code << "  kw = '%'+kw+'%'\n"
    filters = columns.collect do |x|
      'LOWER(CAST('+x.to_s+' AS VARCHAR)) LIKE ?'
    end
    values = '['+(['kw']*columns.size).join(', ')+']'
    for k, v in options[:filters]
      filters << k
      v = '['+v.join(', ')+']' if v.is_a? Array
      values += "+"+v
    end
    code << "  #{conditions}[0] += ' AND (#{filters.join(' OR ')})'\n"
    code << "  #{conditions} += #{values}\n"
    code << "end\n"
    code << "#{conditions}"
    return code.c
  end


  # accountancy -> accounts_range_crit
  def self.accounts_range_crit(variable, conditions='c')
    variable = "params[:#{variable}]" unless variable.is_a? String
    code = ""
    # code << "ac, #{variable}[:accounts] = \n"
    code << "#{conditions}[0] += ' AND '+Account.range_condition(#{variable}[:accounts])\n"
    return code.c
  end

  # accountancy -> crit_params
  def self.crit_params(hash)
    nh = {}
    keys = JournalEntry.state_machine.states.collect{|s| s.name}
    keys += [:period, :started_at, :stopped_at, :accounts, :centralize]
    for k, v in hash
      nh[k] = hash[k] if k.to_s.match(/^(journal|level)_\d+$/) or keys.include? k.to_sym
    end
    return nh
  end

  # accountancy -> general_ledger_conditions
  def self.general_ledger_conditions(options={})
    conn = ActiveRecord::Base.connection
    code = ""
    code << "c=['1=1']\n"
    code << journal_period_crit("params")
    code << journal_entries_states_crit("params")
    code << accounts_range_crit("params")
    code << journals_crit("params")
    code << "c\n"
    # list = code.split("\n"); list.each_index{|x| puts((x+1).to_s.rjust(4)+": "+list[x])}
    return code.c # .gsub(/\s*\n\s*/, ";")
  end


  # accountancy -> journal_entries_states_crit
  def self.journal_entries_states_crit(variable, conditions='c')
    variable = "params[:#{variable}]" unless variable.is_a? String
    code = ""
    code << "#{conditions}[0] += ' AND '+JournalEntry.state_condition(#{variable}[:states])\n"
    return code.c
  end

  # accountancy -> journal_period_crit
  def self.journal_period_crit(variable, conditions='c')
    variable = "params[:#{variable}]" unless variable.is_a? String
    code = ""
    code << "#{conditions}[0] += ' AND '+JournalEntry.period_condition(#{variable}[:period], #{variable}[:started_at], #{variable}[:stopped_at])\n"
    return code.c
  end

  # accountancy -> journals_crit
  def self.journals_crit(variable, conditions='c')
    variable = "params[:#{variable}]" unless variable.is_a? String
    code = ""
    code << "#{conditions}[0] += ' AND '+JournalEntry.journal_condition(#{variable}[:journals])\n"
    return code.c
  end

  # management -> moved_conditions
  def self.moved_conditions(model, state='params[:s]')
    code = "\n"
    code << "c||=['1=1']\n"
    code << "if #{state}=='unconfirmed'\n"
    code << "  c[0] += ' AND moved_at IS NULL'\n"
    code << "elsif #{state}=='confirmed'\n"
    code << "  c[0] += ' AND moved_at IS NOT NULL'\n"
    code << "end\n"
    code << "c\n"
    return code.c
  end

  # management -> shipping_conditions
  def self.shipping_conditions(model, state='params[:s]')
    code = "\n"
    code << "c||=['1=1']\n"
    code << "if #{state}=='unconfirmed'\n"
    code << "  c[0] += ' AND sent_at IS NULL'\n"
    code << "elsif #{state}=='confirmed'\n"
    code << "  c[0] += ' AND sent_at IS NOT NULL'\n"
    code << "end\n"
    code << "c\n"
    return code.c
  end

  # management -> prices_conditions
  def self.prices_conditions(options={})
    code = "conditions=[]\n"
    code << "if params[:supplier_id] == 0 \n "
    code << " conditions = ['#{ProductPriceTemplate.table_name}.active = ?', true] \n "
    code << "else \n "
    code << " conditions = ['#{ProductPriceTemplate.table_name}.supplier_id = ? AND #{ProductPriceTemplate.table_name}.active = ?', params[:supplier_id], true]"
    code << "end \n "
    code << "conditions \n "
    return code.c
  end

end
