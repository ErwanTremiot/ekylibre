desc "Removes end spaces"
task :code do
  print " - White spaces: "
  files  = []
  dirs = "{app,bin,config,db,doc,lib,packagers,public,test,vendor}"
  Dir.chdir(Rails.root) do
    files += Dir["Gemfile*"]
    files += Dir["Rakefile"]
    files += Dir["#{dirs}/*.ru"]
    files += Dir["#{dirs}/*.rb"]
    files += Dir["#{dirs}/*.rake"]
    files += Dir["#{dirs}/*.treetop"]
    files += Dir["#{dirs}/*.yml"]
    files += Dir["#{dirs}/*.xml"]
    files += Dir["#{dirs}/*.haml"]
    files += Dir["#{dirs}/*.erb"]
    files += Dir["#{dirs}/*.rjs"]
    files += Dir["#{dirs}/*.js"]
    files += Dir["#{dirs}/*.coffee"]
    files += Dir["#{dirs}/*.scss"]
    files += Dir["#{dirs}/*.sass"]
    files += Dir["#{dirs}/*.css"]
  end
  log = File.open(Rails.root.join("log", "clean-code.log"), "wb")
  log.write "White spaces:\n"
  count = 0
  files.sort!
  for file in files
    next if File.directory?(file)
    original = File.read(file)
    source = original.dup

    # source.gsub!(/(\w+)\ +/, '\1 ')
    source.gsub!(/[\ \t]+\n/, "\n")
    # source.gsub!(/\n+\n$/, "\n")

    if source != original
      log.write " - #{file}\n"
      File.write(file, source)
      count += 1
    end
  end
  log.close
  puts "#{count.to_s.rjust(3)} files updated"
end
