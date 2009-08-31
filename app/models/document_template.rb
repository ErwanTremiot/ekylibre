# == Schema Information
#
# Table name: document_templates
#
#  active       :boolean       not null
#  cache        :text          
#  company_id   :integer       not null
#  country      :string(2)     
#  created_at   :datetime      not null
#  creator_id   :integer       
#  deleted      :boolean       not null
#  id           :integer       not null, primary key
#  language_id  :integer       
#  lock_version :integer       default(0), not null
#  name         :string(255)   not null
#  nature_id    :integer       not null
#  source       :text          
#  updated_at   :datetime      not null
#  updater_id   :integer       
#

class DocumentTemplate < ActiveRecord::Base
  belongs_to :company
  belongs_to :language
  belongs_to :nature, :class_name=>DocumentNature.name
  has_many :documents, :foreign_key=>:template_id

  validates_presence_of :nature_id

  attr_readonly :company_id

  def before_validation
    self.cache = self.class.compile(self.source) # rescue nil
    begin
      self.cache = self.class.compile(self.source) # rescue nil
    rescue Exception => e
      self.errors.add(:source, e.message)
    end  
  end

  def validates
    errors.add(:source, 'est invalide') if self.cache.nil?
  end

  def destroyable?
    true
  end



  def print(*args)
    # Analyze parameters
    object = args[0]
    raise Exception.new("Must be an activerecord") unless object.class.ancestors.include?(ActiveRecord::Base)

    # Try to find an existing archive
    if self.nature.to_archive
      document = self.documents.find(:first, :conditions=>["owner_id = ? and owner_type = ?", object.id, object.class.name], :order=>"created_at DESC")
      begin
        return document.data if document
      rescue
        
      end
    end

    # Build the PDF data
    pdf = eval(self.cache)

    # Archive the document if necessary
    if self.nature.to_archive
      document = self.archive(object, pdf, :extension=>'pdf')
    end
    
    return pdf
  end


  def archive(owner, data, attributes={})
    document = self.documents.new(attributes.merge(:company_id=>owner.company_id, :owner_id=>owner.id, :owner_type=>owner.class.name))
    method_name = [:document_name, :number, :code, :name, :id].detect{|x| owner.respond_to?(x)}
    document.printed_at = Time.now
    document.extension ||= 'bin'
    document.subdir = Date.today.strftime('%Y-%m')
    document.original_name = owner.send(method_name).to_s.simpleize+'.'+document.extension.to_s
    document.filename = owner.send(method_name).to_s.codeize+'-'+document.printed_at.to_i.to_s(36).upper+'-'+Document.generate_key+'.'+document.extension.to_s
    document.filesize = data.length
    document.sha256 = Digest::SHA256.hexdigest(data)
    document.crypt_mode = 'none'
    if document.save
      File.makedirs(document.path)
      File.open(document.file_path, 'wb') {|f| f.write(data) }
    else
      raise Exception.new document.errors.inspect
    end
    return document
  end


  def self.compile(source)
    file = "#{RAILS_ROOT}/tmp/pt_compile-"+Time.now.strftime("%Y%m%d-%H%M%S")+"-"+rand.to_s+".xml"
    File.open(file, 'wb') {|f| f.write(source)}
    xml = LibXML::XML::Document.file(file)
    template = xml.root
    # raise Exception.new template.find('*').to_a.inspect
    code = ''
    i = 0
    parameters = template.find('parameters/parameter')
    if parameters.size > 0
      code << "raise ArgumentError.new('Unvalid number of argument') if args.size != #{parameters.size}\n"
      parameters.each do |p|
        code << "#{p.attributes['name']} = args[#{i}]\n"
        i+=1
      end
    end
    
    code << "doc = Ibeh.document(Hebi::Document.new, self) do |ibeh|\n"

    document = template.find('document')[0]
    document.find('page').each do |page|
      code += "ibeh.page(#{parameters(page, 'ERROR')[0]}) do |p|\n"
      page.each_element do |element|
        name = element.name.to_sym
        code += compile_element(element, 'p') if [:table, :part].include? name
      end
      code += "end\n"
    end
    
    code << "end\n"
    #code << "File.open('/tmp/test.pdf', 'wb') {|f| f.write(doc.generate)}\n"
    #code << "@current_company.archive(@template, pdf);pdf"
    code << "doc.generate"

    File.delete(file)

    list = code.split("\n"); list.each_index{|x| puts((x+1).to_s.rjust(4)+": "+list[x])}
    return '('+code.gsub(/\s*\n\s*/, ';')+')'
  end

  private


  class << self
    
    SET_ELEMENTS = {
      :page=>[:format],
      :part=>[:height],
      :table=>[:collection],
      :list=>[:collection],
      :column=>[:label, :property, :width],
      :set=>[],
      :font=>[],
      :text=>[:value],
      :cell=>[:value, :width],
      :rectangle=>[:width, :height],
      :line=>[:path],
      :image=>[:value, :width, :height]
    }
    

    def str_to_measure(string, nvar)
      string = string.to_s
      '('+if string.match(/\-?\d+(\.\d+)?mm/)
            string[0..-3]+'.mm'
          elsif string.match(/\-?\d+(\.\d+)?\%/)
            string[0..-2].to_f == 100 ? "#{nvar}.width" : (string[0..-2].to_f/100).to_s+"*#{nvar}.width"
          elsif string.match(/\-?\d+(\.\d+)?/)
            string
          else
            " (0) "
          end+')'
    end

    
    def attr_to_s(k, v, nvar)
      case(k)
      when :align, :valign then
        ":#{v.strip.gsub(/\s+/,'_')}"
      when :top, :left, :right, :width, :height, :size, :border_width then
        str_to_measure(v, nvar)
      when :margin, :padding then
        '['+v.strip.split(/\s+/).collect{|m| str_to_measure(m, nvar)}.join(', ')+']'
      when :border then
        border = v.strip.split(/\s+/)
        raise Exception.new("Attribute border malformed: #{v.inspect}. Ex.: '1mm solid #123456'") if border.size!=3
        "{:width=>#{str_to_measure(border[0], nvar)}, :style=>:#{border[1]}, :color=>#{border[2].inspect}}"
      when :collection then
        v
      when :property then
        "'"+v.gsub(/\//, '.')+"'"
      when :resize, :fixed, :bold, :italic then
        v == "true" ? "true" : "false"
      when :value
        v = v.inspect.gsub(/\{\{[^\}]+\}\}/) do |m|
          data = m[2..-3].to_s.split('?')
          datum = data[0].gsub('/', '.')
          datum = case data[1].to_s.split('=')[0]
                  when 'format'
                    "::I18n.localize(#{datum}, :format=>:legal)"
                  else
                    datum
                  end
          "\"+#{datum}.to_s+\""
        end
        v = v[3..-1] if v.match(/^\"\"\+/)
        v = v[0..-4] if v.match(/\+\"\"$/)
        v
      when :path
        '['+v.split(/\s*\;\s*/).collect{|point| '['+point.split(/\s*\,\s*/).collect{|m| str_to_measure(m, nvar)}.join(', ')+']'}.join(', ')+']'
      else
        v.inspect
      end
    end




    def parameters(element, nvar)
      name = element.name.to_sym
      attributes, parameters = {}, []
      element.attributes.to_h.collect{|k,v| attributes[k.to_sym] = v}
      (SET_ELEMENTS[name]||[]).each{|attr| parameters << attr_to_s(attr, attributes.delete(attr), nvar)}
      attributes.delete(:if)
      attrs = attrs_to_s(attributes, nvar)
      attrs = ', '+attrs if !attrs.blank? and parameters.size>0
      return parameters.join(', ')+attrs, parameters, attributes
    end




    def attrs_to_s(attrs, nvar)
      attrs.collect{|k,v| ":#{k}=>#{attr_to_s(k, v, nvar)}"}.join(', ')
    end
    
    def compile_element(element, variable='x', depth=0, skip=false)
      nvar = 'r'+depth.to_s
      code  = ''

      code += "#{variable}.#{element.name}(#{parameters(element, variable)[0]}) do |#{nvar}|\n" unless skip
      element.each_element do |x|
        name = x.name.to_sym
        if name == :set
          code += compile_element(x, nvar, depth+1)
        elsif name == :image
          params, p, attrs = parameters(x,nvar)
          code += "  if File.exist?((#{p[0]}).to_s)\n"
          code += "    #{nvar}.#{name}(#{params})\n"
          code += "  else\n"
          code += compile_element(x, nvar, depth, true)
          code += "  end\n"        
        else
          code += "  #{nvar}.#{name}(#{parameters(x,nvar)[0]})\n"
        end
      end
      unless skip
        code += "end"
        code += " if #{element.attributes['if'].gsub(/\//,'.')}" if element.attributes['if']
        code += "\n"
      end
      code.gsub(/^/, '  ')
    end
  end
  

end