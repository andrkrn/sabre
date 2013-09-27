module Sabre
  class Hotel
    attr_accessor :area_id, :name, :address, :country, :phone, :fax, :location_description, :chain_code, :hotel_code, :latitude, :longitude, :rates, :rating, :amenities, :property_types, :description, :cancellation, :rooms_available, :services, :policies, :attractions, :cancel_code, :rate_level_code, :taxes

    def initialize(basic_info)
      @area_id = basic_info[:@area_id]
      @name = basic_info[:@hotel_name].titleize
      if basic_info[:address][:tpa_extensions]
        @address = basic_info[:address][:tpa_extensions][:address_line].compact
      else
        @address = basic_info[:address][:address_line].compact
      end
      @country = basic_info[:address][:country_code]
      @phone = basic_info[:contact_numbers][:contact_number][:@phone]
      @fax = basic_info[:contact_numbers][:contact_number][:@fax]
      @chain_code = basic_info[:@chain_code]
      @hotel_code = basic_info[:@hotel_code]
      if basic_info[:position]
        @latitude = basic_info[:position][:@latitude]
        @longitude = basic_info[:position][:@longitude]
      else
        @latitude = basic_info[:@latitude]
        @longitude = basic_info[:@longitude]
      end
      if basic_info[:award]
        @rating = basic_info[:award][:@provider].gsub("NTM","").gsub(" CROWN","").strip
      elsif basic_info[:property]
        @rating = basic_info[:property][:text].gsub("NTM","").gsub(" CROWN","").strip
      end
      if basic_info[:taxes]
        tax = basic_info[:taxes][:text]
        tax = tax.first if tax.is_a? Array
        unless tax.nil?
          @taxes = tax.gsub("PCT","").gsub("TTL","").strip
        end
      end
    end

    def self.find_by_geo(session, start_time, end_time, latitude, longitude, guest_count = 2, amenities = [], chain_codes = [], contract_rate_plans = [], num_properties = 40)
      rate_plan_codes = []
      amenities = amenities.each{|a|a.upcase} unless amenities.empty?
      unless contract_rate_plans.nil?
        unless contract_rate_plans.empty?
          rate_plan_codes = ['GOV','N']
        end
      end
      raise SabreException::SearchError, 'No results found when missing latitude and longitude' if latitude.to_f == 0.0 || longitude.to_f == 0.0
      hotel_attr = {
        'HotelRef' => { 'Latitude' => latitude, 'Longitude' => longitude },
        'RefPoint' => { 'Sort' => 'true', 'GeoCode' => 'true' },
      }
      unless chain_codes.nil?
        chain_codes.each do |cc|
          hotel_attr.merge!({'HotelRef' => { 'ChainCode' => cc }})
        end
      end
      client = Sabre.client('OTA_HotelAvailLLS2.1.0RQ.wsdl')
      response = client.request('OTA_HotelAvailRQ', Sabre.request_header('2.1.0')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ')
        soap.body = {
          'AvailRequestSegment' => {
            #'AdditionalAvail' => '',
            'GuestCounts' => '',
            'HotelSearchCriteria' => {
               'Criterion' => {
                 'HotelAmenity' => amenities, 'HotelRef' => '', 'RefPoint' => '',
                  :attributes! => hotel_attr
               }
            },
            'RatePlanCandidates' => {
                'ContractNegotiatedRateCode' => contract_rate_plans,
                #'RatePlanCode' => rate_plan_codes,
                'RateRange' => '', :attributes! => { 'RateRange' => { 'CurrencyCode' => 'USD', 'Max' => '1000.00', 'Min' => '20.00' }}
              },
              'TimeSpan' => '',
              :attributes! => {
                'TimeSpan' => { 'Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d') },
                'RatePlanCandidates' => { 'PromotionalSpot' => 'L', 'RateAssured' => 'true','SuppressRackRate' => 'false' },
                'HotelSearchCriteria' => { 'NumProperties' => num_properties },
                'GuestCounts' => { 'Count' => guest_count }#,
                #'AdditionalAvail' => { 'Ind' => 'true' }
              }
            }
          }
      end
      construct_response_hash(response)
    end

    def self.find_by_iata(session, start_time, end_time, iata_city_code, guest_count, amenities = [])
      raise SabreException::SearchError, 'Missing IATA City Code - No search results found' if iata_city_code.nil?
      client = Sabre.client('OTA_HotelAvailLLS2.0.0RQ.wsdl')
      response = client.request('OTA_HotelAvailRQ', Sabre.request_header('2.0.0')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ')
        soap.body = {
          'AvailRequestSegment' => {
              'GuestCounts' => '',
              'HotelSearchCriteria' => {
                'Criterion' => {
                  'HotelAmenity' => amenities.map(&:upcase), 'HotelRef' => '', :attributes! => {
                    'HotelRef' => { 'HotelCityCode' => iata_city_code }
                  } }
              },
              'TimeSpan' => '',
              :attributes! => {
                'TimeSpan' => { 'Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d') },
                'HotelSearchCriteria' => { 'NumProperties' => 20 },
                'GuestCounts' => { 'Count' => guest_count }
              }
           }
       }
      end
      construct_response_hash(response)
    end

    def self.change_aaa(session)
      client = Sabre.client('ChangeAAALLS1.1.1RQ.wsdl',1)
      response = client.request('ChangeAAARQ', Sabre.request_old_header('1.1.1')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Change AAA','sabreXML','ChangeAAALLSRQ')
        soap.body = {
          'POS' => Sabre.pos,
          'AAA' => '',
          :attributes! => {
            'AAA' => { 'PseudoCityCode' => Sabre.pcc }
          }
        }
      end
      #result = response.to_hash[:change_aaars]
      response.to_hash[:change_aaars]
      #raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors]
      #return response
    end

    def self.context_change(session)
      client = Sabre.client('ContextChangeLLS2.0.2RQ.wsdl')
      response = client.request('ContextChangeRQ', Sabre.request_header('2.0.2')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Change AAA','sabreXML','ContextChangeLLSRQ')
        soap.body = {
          'ChangeAAA' => '',
          :attributes! => {
            'ChangeAAA' => { 'PseudoCityCode' => Sabre.pcc }
          }
        }
      end
      #result = response.to_hash[:change_aaars]
      response.to_hash[:context_change_rs]
      #raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors]
      #return response
    end

    def self.rate_details(session, line_number)
      client = Sabre.client('HotelRateDescriptionLLS2.0.0RQ.wsdl')
      response = client.request('HotelRateDescriptionRQ', Sabre.request_header('2.0.0')) do
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

    def self.profile(session,hotel_id, start_time, end_time, guest_count, contract_rate_plans = [])
      client = Sabre.client('HotelPropertyDescriptionLLS2.0.1RQ.wsdl')
      response = client.request('HotelPropertyDescriptionRQ', Sabre.request_header('2.0.1')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Description','sabreXML','HotelPropertyDescriptionLLSRQ')
        soap.body = {
          'AvailRequestSegment' => {
            'GuestCounts' => '',
            'HotelSearchCriteria' => {
               'Criterion' => {
                  'HotelRef' => '', :attributes! => {
                    'HotelRef' => { 'HotelCode' => hotel_id }
                  }
               }
            },
            'RatePlanCandidates' => {
              'ContractNegotiatedRateCode' => contract_rate_plans
            },
            'TimeSpan' => '',
              :attributes! => {
                'TimeSpan' => { 'Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d') },
                'GuestCounts' => { 'Count' => guest_count }
            }
          }
	    	}
	    end
	    result = response.to_hash[:hotel_property_description_rs]

	    raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors]
	    return construct_full_response_hash(response)
    end

    def self.find_by_code(session,hotel_id)
    	client = Sabre.client('HotelPropertyDescriptionLLS2.0.1RQ.wsdl')
	    response = client.request('HotelPropertyDescriptionRQ', Sabre.request_header('2.0.1')) do
        Sabre.namespaces(soap)
		    soap.header = session.header('Hotel Description','sabreXML','HotelPropertyDescriptionLLSRQ')
		    soap.body = {
            'AvailRequestSegment' => {
                'HotelSearchCriteria' => {
                      'Criterion' => { 'HotelRef' => '', :attributes! => {
                        'HotelRef' => { 'HotelCode' => hotel_id }
                      } }
                 }
            }
	    	}
	    end
	    result = response.to_hash[:hotel_property_description_rs]
	    raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors]
	    return construct_full_response_hash(response)
    end

    private
    def self.construct_response_hash(results)
      hotels = []
      response = results.to_hash[:ota_hotel_avail_rs]
      unless response[:application_results][:error]
        if response[:errors].nil?
          options = response[:availability_options]

          if options
            options[:availability_option].each do |p|
              prop_info = p[:basic_property_info]
              #street, city, state, postal_code = sanitize_address(
              #  prop_info[:address][:address_line].first.titleize,
              #  prop_info[:address][:address_line].last.split(' ')
              #)

              hotel = Hotel.new(prop_info)
              hotel.location_description = prop_info[:location_description][:text]

              rate_level_code = 'RAC'

              if prop_info[:room_rate].is_a? Array
                prop_info[:room_rate].each do |room_rate|
                  if room_rate.is_a? Hash
                    cp = room_rate[:additional_info][:cancel_policy]
                    hotel.cancel_code = [cp[:@numeric],cp[:@option]].join('')
                    rate_level_code = room_rate[:@rate_level_code]
                    #hotel.rate_code = room_rate[:hotel_rate_code]
                  end
                end
              else
                room_rate = prop_info[:room_rate]
                if room_rate
                  cp = room_rate[:additional_info][:cancel_policy]
                  hotel.cancel_code = [cp[:@numeric],cp[:@option]].join('')
                  rate_level_code = room_rate[:@rate_level_code]
                end
              end

              rates = []
              if rate_range = prop_info[:rate_range]
                rates << {description: 'Minimum', rate_level_code: rate_level_code, amount: rate_range[:@min], currency: rate_range[:@currency_code]}
                rates << {description: 'Maximum', rate_level_code: rate_level_code, amount: rate_range[:@max], currency: rate_range[:@currency_code]}
              end

              hotel.rates = rates

              hotel.amenities = prop_info[:property_option_info].map do |key, val|
                 key.to_s if val[:@ind] == 'true'
              end.compact.uniq

              hotels << hotel
            end
          else
            raise SabreException::SearchError, Sabre.error_message(response) if response[:errors]
          end
        else
          raise SabreException::SearchError, Sabre.error_message(response) if response[:errors]
        end
      end
      return hotels
    end

    def self.construct_full_response_hash(result)
      hotel = nil
      response = result.to_hash[:hotel_property_description_rs]
      if response[:errors].nil?
        room_stay = response[:room_stay]
        #puts "Room stay is #{room_stay}"
        if room_stay[:basic_property_info]
          prop_info = room_stay[:basic_property_info]

          hotel = Hotel.new(prop_info)
          cards = []
          room_stay = response[:room_stay]
          if room_stay[:rate_plans]
            room_stay[:rate_plans][:rate_plan][:guarantee][:guarantees_accepted][:guarantee_accepted][:payment_card].each do |cc|
              cards << cc[:@card_type]
            end
          end
        end

        rates = []
        line_number = nil
        if room_stay[:room_rates]
          if room_stay[:room_rates][:room_rate]
            room_rate = room_stay[:room_rates][:room_rate]
            if room_rate.class.name == 'Array'
              room_rate.each do |rr|
                rates = room_rate_builder(rr, rates)
              end
            else
              rates = room_rate_builder(room_rate, rates)
            end
          elsif room_stay[:room_plans]
            room_stay[:room_plans][:room_plan].each do |rr|
              if rr[:rates]
                tax, total = tax_rate(rr)

                rates << {
                  description: rate_description(rr),
                  night_list_price: rr[:rates][:rate][:@amount],
                  currency: rr[:rates][:rate][:@currency_code],
                  taxes: tax,
                  total_list_price: total
                }
              end
            end
          end
          hotel.rates = rates
        end # End building rates

        points_of_interest = []
        begin
          prop_info[:index_data][:index].each do |poi|
            pt = poi[:@point]
            distance = poi[:@distance_direction].strip
          end
          points_of_interest << {:point => pt, :distance_direction => distance}
        rescue
        end
        #hotel.points_of_interest

        details = {}
        begin
          details = prop_info[:vendor_messages]
          hotel.description = details[:description][:text].join(' ').split('. ').map{|sentence| sentence.capitalize}.join('. ')
          hotel.rooms_available = details[:rooms][:text]
          hotel.cancellation = details[:cancellation][:text].join(' ').split('. ').map{|sentence| sentence.capitalize}.join('. ')
          hotel.location_description = details[:location][:text] if details[:location]
          hotel.services = details[:services][:text]
          hotel.policies = details[:policies][:text]
          hotel.attractions = details[:attractions][:text]
        rescue
        end

        hotel.amenities = prop_info[:property_option_info].map do |key, val|
          if val.is_a? Hash
            key.to_s.gsub('_', ' ').titleize if val[:@ind] == 'true'
          else
            key.to_s.gsub('_', ' ').titleize if val == 'Y'
          end
        end.compact

        hotel.property_types = prop_info[:property_type_info].map do |key, val|
          key.to_s.gsub('_', ' ').titleize if val[:@ind] == 'true'
        end.compact
      else
        raise SabreException::SearchError, Sabre.error_message(p) if response[:errors]
      end
      return hotel
    end

    def self.room(response)
      stay = response[:hotel_rate_description_rs][:room_stay]
      if stay[:basic_property_info][:vendor_messages]
        cancellation = stay[:basic_property_info][:vendor_messages][:cancellation][:text].each{|text|text.to_s}.join(" ")
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
              d = Date.strptime(day[:@effective_date], '%m-%d')
              d += 1.year if d < Date.today
              nightly_rates.merge!({d.strftime('%a %B %d, %Y') => day[:@amount]})
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
