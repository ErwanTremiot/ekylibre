#
# desc "Update fixes for SQL Server in lib/fix_sqlserver.rb"
task :sqlserver_fixes => :environment do
  
  models = models_in_file

  code = ""
  fixes = 0
  for model in models
    cols = []
    for column in model.columns.sort{|a,b| a.name<=>b.name}
      cols << column.name if column.type == :date
    end
    fixes += cols.size
    code += "  #{model.name}.coerce_sqlserver_date "+cols.sort.collect{|x| ":#{x}"}.join(", ")+"\n" unless cols.blank?
  end
  puts " - SQL Server fixes: #{fixes} columns"

  File.open(Rails.root.join("lib", "ekylibre", "sqlserver_date_support.rb"), "wb") do |f|
    f.write("# Autogenerated from Ekylibre (`rake clean:fix_sqlserver` or `rake clean`)\n")
    f.write("if ActiveRecord::Base.connection.adapter_name == 'SQLServer'\n")
    f.write("  Time::DATE_FORMATS[:db] = \"%Y-%m-%dT%H:%M:%S\"\n")
    f.write(code)
    f.write("end\n")
  end
end