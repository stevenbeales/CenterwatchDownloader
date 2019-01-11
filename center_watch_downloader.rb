require 'watir-classic'
require 'csv'
require 'cgi'

File.delete('studies5.csv') if File.exist?('studies5.csv')

begin
  csv = CSV.open('studies5.csv', 'wb')
  csv << %w(Condition TherapeuticArea Summary Purpose Gender Age Status CWid
            Modified Sponsor Phase FacilityType Location Breadcrumbs
            Overview Eligibility MoreInfo Contact)

  browser = Watir::Browser.new
  browser.goto 'http://www.centerwatch.com/clinical-trials/listings/default.aspx?View=All'

  all_links = browser.links.collect { |link| link.href if link.href =~ %r{clinical-trials/listings/condition} and !link.href.include? 'NewOnly' }

  all_links = all_links.uniq!.compact!

  study_links = []

  all_links.each do |link|
    browser.goto link
    puts link
    study_links = browser.links.collect { |alink| alink.href if alink.href =~ %r{clinical-trials/listings/studydetails} }.uniq!.compact!
    study_links.each do |study|
      genderindex = -1
      phaseindex = -1
      ageindex = -1
      statusindex = -1
      sponsorindex = -1
      facilityindex = -1
      durationindex = -1

      puts study
      browser.goto study
      summary = browser.span(:id, /StudyTitle/).text unless
                  browser.span(:id, /StudyTitle/).nil?
      purpose = browser.ps[4].text if browser.ps.count > 4

      # sometimes purpose is not enclosed in P tag
      purpose = '' if purpose.include?('CW ID')

      condition_array = browser.links.collect { |alink| alink if alink.href =~ %r{clinical-trials/listings/condition} }.uniq!.compact!
      condition = condition_array[0].text if condition_array.count > 0
      location_array = browser.links.collect { |alink| alink if alink.href =~ %r{clinical-trials/listings/location} }.uniq!.compact!
      location = location_array[0].text if location_array.count > 0
      breadcrumbs = browser.div(:id, 'SupplementaryBreadcrumbs').html
      overview = browser.div(:id, 'Overview').html
      eligibility = if browser.div(:id, 'Eligibility').exists?
                      browser.div(:id, 'Eligibility').html
                    else
                      ''
                    end
      more_info = if browser.div(:id, 'MoreInfo').exists?
                    browser.div(:id, 'MoreInfo').html
                  else
                    ''
                  end

      contact = browser.div(:id, 'Contact').html

      ta_array = browser.links.collect { |a| a if a.href =~ %r{clinical-trials/listings/therapeutic} }.uniq!.compact!
      temp = ''
      ta_array.each { |ta| temp = temp + ta.text + ' ' }
      therapeuticarea = temp.chop
      browser.dts.each_with_index do |dt, j|
        if dt.id =~ /GenderBlock/
          genderindex = j
        elsif dt.id =~ /PhaseBlock/
          phaseindex = j
        elsif dt.id =~ /AgeBlock/
          ageindex = j
        elsif dt.id =~ /StatusBlock/
          statusindex = j
        elsif dt.id =~ /SponsorBlock/
          sponsorindex = j
        elsif dt.id =~ /FacilityTypeBlock/
          facilityindex = j
        elsif dt.id =~ /DurationBlock/
          durationindex = j
        end
      end
      # if we have missing phase, dd indexes shift down 1 because of empty <dd>
      if phaseindex == -1
        genderindex += 1 if genderindex > -1
        ageindex += 1 if ageindex > -1
        sponsorindex += 1 if sponsorindex > -1
        statusindex += 1 if statusindex > -1
        facilityindex += 1 if facilityindex > -1 && durationindex == -1
      end
      facilityindex += 1 if facilityindex > -1 # facility preceeded by empty dd
      if genderindex > -1
        gender = browser.dt(:id, /GenderBlock/).parent.dd(:index, genderindex).text
      end
      if phaseindex > -1
        phase = browser.dt(:id, /PhaseBlock/).parent.dd(:index, phaseindex).text
      end
      if ageindex > -1
        age = browser.dt(:id, /AgeBlock/).parent.dd(:index, ageindex).text
      end
      if statusindex > -1
        status = browser.dt(:id, /StatusBlock/).parent.dd(:index, statusindex).text
      end
      if sponsorindex > -1
        sponsor = browser.dt(:id, /SponsorBlock/).parent.dd(:index, sponsorindex).text
      end
      if facilityindex > -1
        facility = browser.dt(:id, /FacilityTypeBlock/).parent.dd(:index, facilityindex).text
      end
      cwid = study.split(//).last(6).join
      modified = ''
      csv << [condition, therapeuticarea, summary, purpose, gender, age, status,
              cwid, modified, sponsor, phase, facility, location, breadcrumbs,
              overview, eligibility, more_info, contact]
    end
  end
rescue StandardError => e
  puts e.message
  puts e.backtrace.inspect
ensure
  csv.close
end
