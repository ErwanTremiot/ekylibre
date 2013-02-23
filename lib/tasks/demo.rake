# -*- coding: utf-8 -*-

require 'ostruct'

namespace :db do
  desc "Build demo data"
  task :demo => :environment do
    STDOUT.sync = true
    puts "Started: "
    ActiveRecord::Base.transaction do

      # Import accountancy
      file = Rails.root.join("test", "fixtures", "files", "general_ledger-istea.txt")
      picture_undefined = Rails.root.join("test", "fixtures", "files", "portrait-undefined.png")
      journals = {
        "2" => "BILAN DEBUT",
        "8" => "BILAN CLOTURE",
        "11" => "CAISSE 1",
        "21" => "CRCA",
        "22" => "BANQUE 2",
        "30" => "STOCKS DEBUT COMPTABLE",
        "31" => "STOCKS FIN COMPTABLE",
        "32" => "STOCK DEBUT ECO",
        "33" => "STOCK FIN ECO EXT N+1",
        "35" => "OPER ECO EXERC N",
        "41" => "C-C-POSTAUX",
        "50" => "OISE FORCE",
        "51" => "SAINTE-ANNE MORTE SAISON",
        "60" => "ACHATS FOURNIS COLLECT",
        "70" => "VENTES CLIENTS COLLECTIF",
        "79" => "VENTES CLIENTS GEST COMM",
        "82" => "DEDUCT/REINT EXTRA-COMPT",
        "83" => "REAJUST. FICHE GESTION",
        "84" => "REFERENCES N-1",
        "90" => "OPERATION DIVERSES",
        "91" => "O.D. CENTRALISAT. TVA",
        "92" => "OPER ASSEMBLEE GENERALE",
        "93" => "OPER FIN EX EXT N+1",
        "95" => "OPER. FIN EXERCICE",
        "96" => "DETTES FIN EXER 401",
        "97" => "CREANCES FIN EXER. 411",
        "98" => "DETTES PROVISIONNEES",
        "101" => "CORRECTIF FISCAL (COUT)",
        "102" => "CORRECTIF ECO (COUT)",
        "103" => "CORRECT FISC (COUT) TERRE",
        "104" => "CORRECT ECO (COUT) TERRE",
        "105" => "COUT FISC CULT N-1 TERRE",
        "106" => "COUT ECO CULT N-1 TERRE"
      }

      fy = FinancialYear.first
      fy.started_on = Date.civil(2000,1,1)
      fy.stopped_on = Date.civil(2000,12,31)
      fy.code = "EX2000"
      fy.save!
      en_org = EntityNature.where(:gender => :undefined).first

      CSV.foreach(file, :encoding => "CP1252", :col_sep => ";") do |row|
        jname = (journals[row[1]] || row[1]).capitalize
        r = OpenStruct.new(:account => Account.get(row[0]),
                           :journal => Journal.find_by_name(jname) || Journal.create!(:name => jname, :code => row[1]),
                           :page_number => row[2], # What's that ?
                           :printed_on => Date.civil(*row[3].split(/\-/).map(&:to_i)),
                           :entry_number => row[4],
                           :entity_name => row[5],
                           :entry_name => row[6],
                           :debit => row[7].to_d,
                           :credit => row[8].to_d,
                           :vat => row[9],
                           :comment => row[10],
                           :letter => row[11],
                           :what_on => row[12])


        fy = FinancialYear.at(r.printed_on)
        unless entry = JournalEntry.find_by_journal_id_and_number(r.journal.id, r.entry_number)
          number = r.entry_number.to_s.gsub(/[^A-Z0-9]/, '')
          number = r.journal.code + rand(10000000000).to_s(36) if number.blank?
          entry = r.journal.entries.create!(:printed_on => r.printed_on, :number => number.upcase)
        end
        column = (r.debit.zero? ? :credit : :debit)
        entry.send("add_#{column}", r.entry_name, r.account, r.send(column))
        if r.account.number.match(/^401/)
          unless Entity.find_by_origin(r.entity_name)
            f = File.open(picture_undefined)
            entity = Entity.create!(:last_name => r.entity_name.mb_chars.capitalize, :nature_id => en_org.id, :supplier_account_id => r.account_id, :picture => f, :origin => r.entity_name)
            f.close
            entity.addresses.create!(:canal => :email, :coordinate => ["contact", "info", r.entity_name.parameterize].sample + "@" + r.entity_name.parameterize + "." + ["fr", "com", "org", "eu"].sample)
            entity.addresses.create!(:canal => :phone, :coordinate => "+33" + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s)
          end
        end
        if r.account.number.match(/^411/)
          unless Entity.find_by_origin(r.entity_name)
            f = File.open(picture_undefined)
            entity = Entity.create!(:last_name => r.entity_name.mb_chars.capitalize, :nature_id => en_org.id, :client_account_id => r.account_id, :picture => f, :origin => r.entity_name)
            f.close
            entity.addresses.create!(:canal => :email, :coordinate => ["contact", "info", r.entity_name.parameterize].sample + "@" + r.entity_name.parameterize + "." + ["fr", "com", "org", "eu"].sample)
            entity.addresses.create!(:canal => :phone, :coordinate => "+33" + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s + rand(10).to_s)
          end
        end

        print "."
      end

      # Import synel
      v = ProductVariety.find_by_code("cattle")
      p = ProductVariety.find_by_code("animal")
      v ||= ProductVariety.create!(:name => "Bovin", :code => "cattle", :product_type => "Animal", :parent_id => (p ? p.id : nil))
      unit = Unit.find_by_base("")
      # add default variety for building
      b = ProductVariety.find_by_code("animal_house")
      q = ProductVariety.find_by_code("building")
      b ||= ProductVariety.create!(:name => "Batiments Animaux", :code => "animal_house", :product_type => "Warehouse", :parent_id => (q ? q.id : nil))
      # add default category for all
      category = ProductNatureCategory.first
      category ||= ProductNatureCategory.create!(:name => "Défaut")
      # create default product_nature to place animal
      place_nature = ProductNature.find_by_number("CATTLE_HOUSE")
      place_nature ||= ProductNature.create!(:name => "Stabulation", :number => "CATTLE_HOUSE", :storage => true, :indivisible => true, :variety_id => b.id, :unit_id => unit.id, :category_id => category.id)
      # create default product_nature to create animal
      cow = ProductNature.find_by_number("CATTLE")
      cow ||= ProductNature.create!(:name => "Bovin", :number => "CATTLE", :alive => true, :storable => true, :indivisible => true, :variety_id => v.id, :unit_id => unit.id, :category_id => category.id)
      # create default product to place animal
      place = Warehouse.find_by_work_number("STABU_01")
      place ||= Warehouse.create!(:name => "Stabulation principale", :identification_number => "S0001", :number => "STABU_01",:work_number => "STABU_01", :born_at => Time.now, :reservoir => true, :content_nature_id => cow.id, :variety_id => b.id, :nature_id => place_nature.id, :owner_id => Entity.of_company.id)

      arrival_causes = {"N" => :birth}
      departure_causes = {"M" => :death, "B" => :consumption}


      file = Rails.root.join("test", "fixtures", "files", "animals-synel17.csv")
      pictures = Dir.glob(Rails.root.join("test", "fixtures", "files", "animals", "*.jpg"))
      CSV.foreach(file, :encoding => "CP1252", :col_sep => ";", :headers => true) do |row|
        next if row[4].blank?
        r = OpenStruct.new(:country => row[0],
                           :identification_number => row[1],
                           :work_number => row[2],
                           :name => (row[3].blank? ? Faker::Name.first_name : row[3].capitalize),
                           :born_on => (row[4].blank? ? nil : Date.civil(*row[4].to_s.split(/\//).reverse.map(&:to_i))),
                           :corabo => row[5],
                           :sex => (row[6] == "F" ? :female : :male),
                           :arrival_cause => (arrival_causes[row[7]] || row[7]),
                           :arrived_on => (row[8].blank? ? nil : Date.civil(*row[8].to_s.split(/\//).reverse.map(&:to_i))),
                           :departure_cause => (departure_causes[row[9]] ||row[9]),
                           :departed_on => (row[10].blank? ? nil : Date.civil(*row[10].to_s.split(/\//).reverse.map(&:to_i)))
                           )
        f = File.open(pictures.sample)
        animal = Animal.create!(:name => r.name, :identification_number => r.identification_number, :work_number => r.work_number, :description => r.arrival_cause, :born_at => r.born_on, :sex => r.sex, :picture => f, :nature_id => cow.id, :number => r.work_number, :owner_id => Entity.of_company.id)
        f.close
        # place the current animal in the default place (stabulation) with dates
        ProductLocalization.create!(:container_id => place.id, :product_id => animal.id, :nature => :interior, :transfer_id => place.id, :started_at => r.arrived_on, :stopped_at => r.departed_on, :arrival_cause => r.arrival_cause, :departure_cause => r.departure_cause)
        print "c"
      end

      # Import shapefile
      v = ProductVariety.find_by_code("land_parcel")
      p = ProductVariety.find_by_code("place")
      v ||= ProductVariety.create!(:name => "Parcelle", :code => "land_parcel", :product_type => "LandParcel", :parent_id => (p ? p.id : nil))
      unit = Unit.get(:m2)
      category = ProductNatureCategory.first
      category ||= ProductNatureCategory.create!(:name => "Défaut")
      land_parcel = ProductNature.find_by_number("LANDPARCEL")
      land_parcel ||= ProductNature.create!(:name => "Parcelle", :number => "LANDPARCEL", :variety_id => v.id, :unit_id => unit.id, :category_id => category.id)
      RGeo::Shapefile::Reader.open(Rails.root.join("test", "fixtures", "files", "land_parcels-shapefile.shp").to_s) do |file|
        # puts "File contains #{file.num_records} records."
        file.each do |record|
          LandParcel.create!(:shape => record.geometry, :name => Faker::Name.first_name, :number => record.attributes['PACAGE'].to_s + record.attributes['CAMPAGNE'].to_s + record.attributes['NUMERO'].to_s, :born_at => Date.civil(2000,1,1), :nature_id => land_parcel.id, :owner_id => Entity.of_company.id)
          # puts "Record number #{record.index}:"
          # puts "  Geometry: #{record.geometry.as_text}"
          # puts "  Attributes: #{record.attributes.inspect}"
          print "p"
        end
      end

      puts "!"
    end
  end
end