module Sabre
  class Hotel
    def self.find_by_geo(session, start_time, end_time, latitude, longitude, guest_count, amenities = [])
      client = Sabre.client('OTA_HotelAvailLLS1.11.1RQ.wsdl')
      response = client.request(:ota_hotel_avail_rq, { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2003/07', 'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'), 'Version' => '2003A.TsabreXML1.11.1'}) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ')
        soap.body = {
          'POS' => Sabre.pos,
          'AvailRequestSegments' => {
            'AvailRequestSegment' => {
              'StayDateRange' => '', 
              'RatePlanCandidates' => {
                'RateRange' => '', :attributes! => { 'RateRange' => { 'CurrencyCode' => 'USD', 'Max' => '1000.00', 'Min' => '20.00' }}
              }, 'RoomStayCandidates' => {
                 'RoomStayCandidate' => { 'GuestCounts' => { 'GuestCount' => '', :attributes! => { 'GuestCount' => { 'Count' => guest_count } } } } 
              }, 'HotelSearchCriteria' => {
                 'Criterion' => { 
                   'HotelAmenity' => amenities, 'HotelRef' => '', 'RefPoint' => 'G', :attributes! => {
                     'HotelRef' => { 'Latitude' => latitude, 'Longitude' => longitude }, 
                     'RefPoint' => { 'GEOCodeOnly' => 'true', 'LocationCode' => 'R' },
                   } 
                 }
              }, :attributes! => { 
                'StayDateRange' => { 'Start' => start_time.strftime('%m-%d'), 'End' => end_time.strftime('%m-%d') }, 
                'RatePlanCandidates' => { 'SuppressRackRate' => 'false' },
                'HotelSearchCriteria' => { 'NumProperties' => 20 } 
              }
            }
          }
        }
      end
  end

    def self.find_by_iata(session, start_time, end_time, iata_city_code, guest_count, amenities = [])
      client = Sabre.client('OTA_HotelAvailLLS1.11.1RQ.wsdl')
      response = client.request(:ota_hotel_avail_rq, { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2003/07', 'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'), 'Version' => '2003A.TsabreXML1.11.1'}) do
        Sabre.namespaces(soap)
        soap.header = session.header('Hotel Availability','sabreXML','OTA_HotelAvailLLSRQ')
        soap.body = {
          'POS' => Sabre.pos,
          'AvailRequestSegments' => {
  'AvailRequestSegment' => {
                'StayDateRange' => '', 
                'RoomStayCandidates' => {
                  'RoomStayCandidate' => { 'GuestCounts' => { 'GuestCount' => '', :attributes! => { 'GuestCount' => { 'Count' => guest_count } } } } 
                }, 'HotelSearchCriteria' => {
                  'Criterion' => { 
                    'HotelAmenity' => amenities, 'HotelRef' => '', :attributes! => {
    'HotelRef' => { 'HotelCityCode' => iata_city_code } 
  } }
   }, :attributes! => { 
    'HotelSearchCriteria' => { 'NumProperties' => 20 }, 
			'StayDateRange' => { 'Start' => start_time.strftime('%m-%dT%H:%M:%S'), 'End' => end_time.strftime('%m-%dT%H:%M:%S') }  
		}
             }
           }
       }
      end
    end

    def self.rate_details(session, hotel_id, visit_start, visit_end, guest_count, line_number)
    	client = Sabre.client('HotelRateDescriptionLLS1.9.1RQ.wsdl')
	    response = client.request(:hotel_rate_description_rq, { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2003/07', 'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'), 'Version' => '1.9.1'}) do
        Sabre.namespaces(soap)
		    soap.header = session.header('Hotel Rates','sabreXML','HotelRateDescriptionLLSRQ')
		    soap.body = {
          'POS' => Sabre.pos,
				  'AvailRequestSegments' => {
					 	'AvailRequestSegment' => {
              'RatePlanCandidates' => { 'RatePlanCandidate' => '', :attributes! => { 'RatePlanCandidate' => { 'RPH' => line_number.to_s }} 
							}
				    }
			    }
	    	}
	    end
	    result = response.to_hash[:hotel_rate_description_rs]
	    raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors] 
	    return response
    end

    def self.profile(session,hotel_id, start_time, end_time, guest_count)
    	client = Sabre.client('HotelPropertyDescriptionLLS1.12.1RQ.wsdl')
	    response = client.request(:hotel_property_description_rq, { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2003/07', 'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'), 'Version' => '2003A.TsabreXML1.11.1'}) do
        Sabre.namespaces(soap)
		    soap.header = session.header('Hotel Description','sabreXML','HotelPropertyDescriptionLLSRQ')
		    soap.body = {
          'POS' => Sabre.pos,
          'AvailRequestSegments' => {
              'AvailRequestSegment' => {
                  'StayDateRange' => '', :attributes! => { 'StayDateRange' => {
                      'Start' => start_time.strftime('%Y-%m-%d'), 'End' => end_time.strftime('%Y-%m-%d')
                  } }, 'RoomStayCandidates' => {
                   'RoomStayCandidate' => { 'GuestCounts' => { 'GuestCount' => '', :attributes! => { 'GuestCount' => { 'Count' => guest_count } } } } 
          }, 'HotelSearchCriteria' => {
                        'Criterion' => { 'HotelRef' => '', :attributes! => {
                          'HotelRef' => { 'HotelCode' => hotel_id }
                        } }
                   }
              }
			    }
	    	}
	    end
	    result = response.to_hash[:hotel_property_description_rs]
	    raise SabreException::ConnectionError, Sabre.error_message(result) if result[:errors] 
	    return response
    end

  end
end
