module Sabre
  module Traveler
    def self.profile(session,first_name,last_name,phone)
      client = Sabre.client('TravelItineraryAddInfoLLS2.0.1RQ.wsdl')
      response = client.request('TravelItineraryAddInfoRQ', Sabre.request_header('2.0.1')) do
        Sabre.namespaces(soap)
        soap.header = session.header('Travel Itinerary Info','sabreXML','TravelItineraryAddInfoLLSRQ')
        soap.body = {
          'AgencyInfo' => { 'Address' => { 
                  'AddressLine' => 'MyTravelersHaven.com',
                  'CityName' => 'DENVER',
                  'CountryCode' => 'US',
                  'PostalCode' => '80246',
                  'StateCountyProv' => '', 
                  'StreetNmbr' => '425 S. Cherry Street',
                  :attributes! => { 'StateCountyProv' => { 'StateCode' => 'CO' } }
              }, 
              'Ticketing' => '',
              :attributes! => { 'Ticketing' => { 'PseudoCityCode' => 'P40G', 'TicketType' => '7T-' } }
          },
          'CustomerInfo' => { 
            'ContactNumbers' => { 'ContactNumber' => '' , :attributes! => { 'ContactNumber' => {
              'Phone' => phone, 'PhoneUseType' => 'H' 
            }}}, 
            'PersonName' => { 'GivenName' => first_name, 'Surname' => last_name }, 
            :attributes! => {
              'PersonName' => { 'NameReference' => 'REF1' } 
            }
          }
        }
      end
    end
    
    def self.locate(session, transaction_code, reservation_id)
      client = Sabre.client('TravelItineraryReadLLS2.2.0RQ.wsdl')
      response = client.request('TravelItineraryReadRQ', Sabre.request_header('2.2.0')) do
        Sabre.namespaces(soap)
	      soap.header = session.header('Travel Itinerary Info','sabreXML','TravelItineraryReadLLSRQ')
	      soap.body = {
            'MessagingDetails' => { 'Transaction' => '', :attributes! => { 'Transaction' => { 'Code' => transaction_code } } },
                'UniqueID' => '', :attributes! => { 'UniqueID' => { 'ID' => reservation_id } } 
        } 
      end
    end
  end
end
