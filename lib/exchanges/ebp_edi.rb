module Exchanges

  class EbpEdi < Exchanger


    # Import from simple files EBP.EDI
    def self.import(company, file, options={})
      File.open(file, "rb:CP1252") do |f|
        unless f.readline.match(/^EBP\.EDI$/)
          raise NotWellFormedFileError.new("Start is not valid")
        end
        encoding = f.readline
        f.readline
        owner = f.readline
        started_on = f.readline
        started_on = Date.civil(started_on[4..7].to_i, started_on[2..3].to_i, started_on[0..1].to_i)          
        stopped_on = f.readline
        stopped_on = Date.civil(stopped_on[4..7].to_i, stopped_on[2..3].to_i, stopped_on[0..1].to_i)          
        ic = Iconv.new("utf-8", "cp1252")
        ActiveRecord::Base.transaction do
          while 1
            begin
              line = f.readline.gsub(/\n/, '')
            rescue
              break
            end
            unless company.financial_years.find_by_started_on_and_stopped_on(started_on, stopped_on)
              company.financial_years.create!(:started_on=>started_on, :stopped_on=>stopped_on)
            end
            line = ic.iconv(line).split(/\;/)
            if line[0] == "C"
              unless company.accounts.find_by_number(line[1])
                company.accounts.create!(:number=>line[1], :name=>line[2])
              end
            elsif line[0] == "E"
              unless journal = company.journals.find_by_code(line[3])
                journal = company.journals.create!(:code=>line[3], :name=>line[3], :nature=>Journal.natures[-1][1].to_s, :closed_on=>started_on-1)
              end
              number = line[4].blank? ? "000000" : line[4]
              line[2] = Date.civil(line[2][4..7].to_i, line[2][2..3].to_i, line[2][0..1].to_i)
              unless entry = journal.entries.find_by_number_and_printed_on(number, line[2])
                entry = journal.entries.create!(:number=>number, :printed_on=>line[2])
              end
              unless account = company.accounts.find_by_number(line[1])
                account = company.accounts.create!(:number=>line[1], :name=>line[1])
              end
              line[8] = line[8].strip.to_f
              if line[7] == "D"
                entry.add_debit(line[6], account, line[8], :letter=>line[10])
              else
                entry.add_credit(line[6], account, line[8], :letter=>line[10])
              end
            end
          end
        end
      end
    end

  end

end