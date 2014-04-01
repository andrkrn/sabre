module Sabre
  class Hotel
    attr_accessor :area_id, :name, :address, :country, :phone, :fax, :location_description,
                  :chain_code, :hotel_code, :latitude, :longitude, :rates, :rating, :amenities,
                  :property_types, :description, :cancellation, :rooms_available, :awards,
                  :services, :transportation, :policies, :attractions, :cancel_code,
                  :rate_level_code, :taxes, :alternates

    def initialize(basic_info)
      @area_id    = basic_info[:@area_id]
      @name       = basic_info[:@hotel_name].titleize
      @country    = basic_info[:address][:country_code]
      @phone      = basic_info[:contact_numbers][:contact_number][:@phone]
      @fax        = basic_info[:contact_numbers][:contact_number][:@fax]
      @chain_code = basic_info[:@chain_code]
      @hotel_code = basic_info[:@hotel_code]
      if basic_info[:address][:tpa_extensions]
        @address  = basic_info[:address][:tpa_extensions][:address_line].compact
      else
        @address  = basic_info[:address][:address_line].compact
      end
      if basic_info[:position]
        @latitude  = basic_info[:position][:@latitude]
        @longitude = basic_info[:position][:@longitude]
      else
        @latitude  = basic_info[:@latitude]
        @longitude = basic_info[:@longitude]
      end
      if basic_info[:award]
        @rating   = basic_info[:award][:@provider].gsub("NTM","").gsub(" CROWN","").strip
      elsif basic_info[:property]
        @rating   = basic_info[:property][:text].gsub("NTM","").gsub(" CROWN","").strip
      end
      if basic_info[:taxes]
        tax       = basic_info[:taxes][:text]
        tax       = tax.first if tax.is_a? Array
        unless tax.nil?
          @taxes  = tax.gsub("PCT","").gsub("TTL","").strip
        end
      end
    end

    # HOTEL AVAILABILITY SEARCH METHODS

    def self.search_client(session, wsdl_url_root)
      client = Savon.client(
        :wsdl => (wsdl_url_root + 'OTA_HotelAvailLLS2.1.0RQ.wsdl'),
        :convert_request_keys_to => :camelcase,
        :env_namespace => 'soap-env',
        :soap_header => session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ'),
        :namespaces => Sabre.namespaces
      )
      return client
    end

    def self.profile_client(session, wsdl_url_root)
      client = Savon.client(
        :wsdl => (wsdl_url_root + 'HotelPropertyDescriptionLLS2.0.1RQ.wsdl'),
        :convert_request_keys_to => :camelcase,
        :env_namespace => 'soap-env',
        :soap_header => session.header('Hotel Description','sabreXML','HotelPropertyDescriptionLLSRQ'),
        :namespaces => Sabre.namespaces
      )
      return client
    end


    def self.search(session, wsdl_url_root, start_time, end_time, args = {})

      default_options = {
        guest_count:    2,
        ntm_rating:     5,
        num_properties: 100,
        amenities: []
      }

      options = default_options.merge(args)

      guest_count    = options[:guest_count]
      ntm_rating     = options[:ntm_rating]
      num_properties = options[:num_properties]
      latitude       = options[:latitude]
      longitude      = options[:longitude]
      city_code      = options[:city_code]
      hotel_code     = options[:hotel_code]
      chain_code     = options[:chain_code]
      amenities      = options[:amenities]

      raise SabreException::SearchError, 'No results found when missing latitude and longitude' if (latitude || longitude) && (latitude.to_f == 0.0 || longitude.to_f == 0.0)

      xml = Builder::XmlMarkup.new
      xml.OTA_HotelAvailRQ({'Version' => "2.1.0"}.merge(Sabre.request_namespaces)) do
        xml.AvailRequestSegment do
          xml.GuestCounts('Count' => guest_count)
          xml.HotelSearchCriteria('NumProperties' => num_properties) do
            xml.Criterion do
              xml.Award('Provider' => 'NTM', 'Rating' => ntm_rating) if ntm_rating > 0
              xml.HotelRef('HotelCityCode' => city_code) unless city_code.blank?
              xml.HotelRef('Latitude' => latitude, 'Longitude' => longitude) if latitude && longitude
              xml.HotelRef('HotelCode' => hotel_code) if hotel_code
              xml.HotelRef('ChainCode' => chain_code) if chain_code
              amenities.each do |amenity|
                xml.HotelAmenity(amenity.upcase)
              end
            end
          end
          xml.TimeSpan('Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d'))
        end
      end

      response = search_client(session, wsdl_url_root).call(:ota_hotel_avail_rq, :message => xml.target!)

      filename = "hotel-search-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      unless Sabre.tmp_directory.blank?
        File.open("#{Sabre.tmp_directory}/#{filename}.xml", 'w') {|f| f.write(response.to_xml) }
        File.open("#{Sabre.tmp_directory}/#{filename}.rb", 'w') {|f| f.write(response.to_hash[:ota_hotel_avail_rs]) }
      end

      return response.to_xml
    end


    def self.find_by_city_code(session, wsdl_url_root, start_time, end_time, city_code, args = {})
      self.search(session, wsdl_url_root, start_time, end_time, {city_code: city_code}.merge(args))
    end


    def self.find_by_geo(session, wsdl_url_root, start_time, end_time, latitude, longitude, args = {})
      self.search(session, wsdl_url_root, start_time, end_time, {latitude: latitude, longitude: longitude}.merge(args))
    end


    def self.find_by_hotel_code(session, wsdl_url_root, start_time, end_time, hotel_code, chain_code, args = {})
      self.search(session, wsdl_url_root, start_time, end_time, {hotel_code: hotel_code, chain_code: chain_code}.merge(args))
    end


    # def self.additional(session, &message)
    #   client = Sabre.client('OTA_HotelAvailLLS2.1.0RQ.wsdl')
    #   response = client.call('OTA_HotelAvailRQ', Sabre.request_header('2.1.0')) do
    #     Sabre.namespaces(soap)
    #     soap.header = session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ')
    #     soap.body = {
    #       'AvailRequestSegment' => {
    #         'AdditionalAvail' => '',
    #           :attributes! => {
    #             'AdditionalAvail' => { 'Ind' => 'true' }
    #           }
    #         }
    #       }
    #   end
    #   construct_response_hash(response, &message)
    # end


    # /HOTEL AVAILABILITY SEARCH METHODS


    # HOTEL PROFILE DETAILS


    def self.profile(session, wsdl_url_root, start_time, end_time, hotel_codes, args = {})

      hotel_codes = [hotel_codes].flatten

      default_options = {
        guest_count:    2
      }

      options     = default_options.merge(args)
      guest_count = options[:guest_count]

      rate_codes  = options[:rate_codes].flatten if options[:rate_codes]

      xml = Builder::XmlMarkup.new
      xml.HotelPropertyDescriptionRQ({'Version' => "2.0.1"}.merge(Sabre.request_namespaces)) do
        xml.AvailRequestSegment do
          xml.GuestCounts('Count' => guest_count)
          xml.HotelSearchCriteria do
            xml.Criterion do
              hotel_codes.each do |hotel_code|
                xml.HotelRef('HotelCode' => hotel_code)
              end
            end
          end
          if rate_codes.present?
            xml.RatePlanCandidates do
              rate_codes.each do |rate_code|
                xml.ContractNegotiatedRateCode(rate_code)
              end
            end
          end
          xml.TimeSpan('Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d'))
        end
      end

      response = profile_client(session, wsdl_url_root).call(:hotel_property_description_rq, :message => xml.target!)

      filename = "hotel-profile-#{hotel_codes.join("-")}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"

      xml_output  = response.to_xml.to_s.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
      ruby_output = response.to_hash[:hotel_property_description_rs].to_s.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})

      unless Sabre.tmp_directory.blank?
        File.open("#{Sabre.tmp_directory}/#{filename}.xml", 'w') {|f| f.write(xml_output) }
        File.open("#{Sabre.tmp_directory}/#{filename}.rb", 'w') {|f| f.write(ruby_output) }
      end

      return response.to_xml
    end

    # /HOTEL PROFILE DETAILS


    def self.rate_details(session, line_number)
      client = Sabre.client('HotelRateDescriptionLLS2.0.0RQ.wsdl')
      response = client.call('HotelRateDescriptionRQ', Sabre.request_header('2.0.0')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Rates','sabreXML','HotelRateDescriptionLLSRQ')
        soap.body = {
          'AvailRequestSegment' => {
            'RatePlanCandidates' => {
              'RatePlanCandidate' => '', :attributes! => { 'RatePlanCandidate' => { 'RPH' => line_number }}
            }
          }
        }
      end
      result = response.to_hash[:hotel_rate_description_rs]
      raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors]
      return room(response)
    end


    private


    def self.room(response)
      stay = response[:hotel_rate_description_rs][:room_stay]
      if stay[:basic_property_info][:vendor_messages]
        cancel_text = stay[:basic_property_info][:vendor_messages][:cancellation][:text]
        if cancel_text.kind_of? Array
          cancellation = cancel_text.each{|text|text.to_s}.join(" ")
        else
          cancellation = cancel_text
        end
      else
        cancellation = nil
      end
      line_number = stay[:basic_property_info][:@rph]
      rates = []
      if stay[:room_rates]
        room_rate = stay[:room_rates][:room_rate]
        if room_rate.class.name == 'Array'
          room_rate.each do |rr|
            rates = room_rate_builder(rr, rates)
          end
        else
          rates = room_rate_builder(room_rate, rates)
        end
        rates = rates.each{|r|r[:line_number] = line_number}
      end
      return rates, cancellation # It is quite possible that the cancellation is null
    end

    def self.rate_description(rate_result)
      description = rate_result[:additional_info][:text]
      description = description.join(' ') if description.kind_of? Array
      description.gsub! /\s?[,|\/],?\s?/, ", "
      description = description.titleize
    end

    def self.tax_rate(room_rate)
      tax = nil
      total = nil
      if room_rate[:rates][:rate]
        if room_rate[:rates][:rate][:hotel_total_pricing]
          total = room_rate[:rates][:rate][:hotel_total_pricing][:@amount]
          taxes = room_rate[:rates][:rate][:hotel_total_pricing][:total_taxes]
          if taxes
          tax = taxes ? taxes[:@amount] : nil
          tax = taxes[:tax_field_one] if tax.nil? && taxes[:tax_field_one].present?
          end
        end
      end
      return tax, total
    end

    def self.room_stay_candidates(number_of_guests)
      {
        'RoomStayCandidate' => {
        }
      }
    end

    def self.room_rate_builder(rr, rates)
      code = rr[:@iata_characteristic_identification]
      product = rr[:@iata_product_identification]
      cancel_policy = rr[:additional_info][:cancel_policy]
      dca_cancellation = rr[:additional_info][:dca_cancellation].nil? ? nil : rr[:additional_info][:dca_cancellation][:text]
      cancellation_details = cancel_policy[:text].nil? ? nil : cancel_policy[:text]
      commission = rr[:additional_info][:commission]
      commission = commission.include?('PERCENT COMMISSION') ? commission.gsub('PERCENT COMMISSION','') : nil
      cancel_code = [cancel_policy[:@numeric],cancel_policy[:@option]].join('')
      line_number = rr[:@rph]
      if rr[:rates]
        # TODO Merge in V2
        nightly_rates = Hash.new
        hotel_total_pricing = rr[:rates][:rate][:hotel_total_pricing]
        if hotel_total_pricing
          visit_range = hotel_total_pricing[:rate_range]
          unless visit_range.nil?
            visit_range.each_with_index do |day,i|
              d_start = Date.strptime(day[:@effective_date], '%m-%d')
              d_end = Date.strptime(day[:@expire_date], '%m-%d')
              d_start += 1.year if d_start < Date.today
              d_end += 1.year if d_end < Date.today
              (d_start..(d_end - 1.day)).map do |date|
                nightly_rates.merge!({date.strftime('%a %B %d, %Y') => day[:@amount]})
              end
            end
          end
        end
        tax, total = tax_rate(rr)
        rates << {
          description: rate_description(rr),
          code: code,
          product: product,
          commission: commission,
          cancel_code: cancel_code,
          cancellation_details: cancellation_details,
          dca_cancellation: dca_cancellation,
          line_number: line_number,
          night_list_price: rr[:rates][:rate][:@amount],
          nightly_prices: nightly_rates,
          currency: rr[:rates][:rate][:@currency_code],
          taxes: tax,
          total_list_price: total
        }
      end
      return rates
    end

  end
end
