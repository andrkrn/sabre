require 'spec_helper'

describe Sabre do
  context "Session Services" do
    let(:client) do
      Savon::Client.new do
        #wsdl.namespace = 'http://wsdl-crt.cert.sabre.com/'
        #wsdl.document = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/tpf/OTA_HotelAvailLLS1.11.1RQ.wsdl'
        #wsdl.document = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
        wsdl.document = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
        #wsdl.document = 'http://sws-crt.cert.sabre.com/sabreXML1.0.00/usg/SessionCreateRQ.wsdl' # This no longer works
      end
    end

    it "expects the client to return soap_actions" do#, :vcr, record: :new_episodes do
      client.wsdl.soap_actions.should == [:session_create_rq]
    end

  end

  context "SOAP Sabre 1.0 Requests" do
    before(:each) do
      #Sabre.cert_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      Sabre.wsdl_url = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/tpf/'
      #endpoint_url: https://webservices.sabre.com/websvc
      Sabre.cert_wsdl_url = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      Sabre.orig_wsdl_url = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/tpf/'
      Sabre.ipcc = 'P40G'
      Sabre.pcc = 'N10G'
      Sabre.conversation_id = 'elia@mytravelershaven.com'
      Sabre.domain = 'hotelengine.com'
      Sabre.username = '7971'
      Sabre.password = 'WS020212'
      @session = Sabre::Session.new('elia@mytravelershaven.com')
    end

    it "should change the AAA for rates" do
      changed = Sabre::Hotel.change_aaa(@session)
      changed.should_not be_nil
    end

    after(:each) do
      @session.close
    end
  end

  context "SOAP Requests" do
    before(:each) do
      #Sabre.cert_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      #Sabre.wsdl_url = 'http://wsdl-crt.cert.sabre.com/wsdl/tpfc/' # 2.0
      Sabre.wsdl_url = 'http://webservices.sabre.com/wsdl/tpfc/' # 2.0
      #Sabre.endpoint_url = 'https://cert-webservices.sabre.com/tsts'
      Sabre.endpoint_url = 'https://webservices.sabre.com/websvc'
      #Sabre.cert_wsdl_url = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      Sabre.cert_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      #Sabre.cert_wsdl_url = 'http://sws-crt.cert.sabre.com/sabreXML1.0.00/usg/SessionCreateRQ.wsdl' # Stopped working... I hate you Sabre
      #Sabre.orig_wsdl_url = 'http://wsdl-crt.cert.sabre.com/sabreXML1.0.00/tpf/'
      Sabre.orig_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/tpf/' # 1.0
      Sabre.ipcc = 'P40G'
      Sabre.pcc = 'N10G'
      Sabre.conversation_id = 'elia@mytravelershaven.com'
      Sabre.domain = 'hotelengine.com'
      Sabre.username = '7971'
      Sabre.password = 'WS020212'
      @session = Sabre::Session.new('elia@mytravelershaven.com')
    end

    it "should create a travel itinerary" do #, :vcr, record: :new_episodes do
      response = Sabre::Traveler.profile(@session, Faker::Name.first_name, Faker::Name.last_name, '303-861-9300')
      response.to_hash.should include(:travel_itinerary_add_info_rs)
    end

    it "should return a list of hotels given a valid availability request" do #, :vcr, record: :new_episodes do
      st = DateTime.now
      hotels = Sabre::Hotel.find_by_geo(@session, (Time.now+172800), (Time.now+432000),
        '37.7838', '-122.4176','1',[],[],[],25)
      puts "Time elapsed #{(DateTime.now - st).to_f}"
      hotel = hotels.sample
      hotel.latitude.should_not be_nil
      hotels.map(&:cancel_code).should include('06P')
      hotels.size.should > 0
    end

    it "should return a list of hotels given a valid availability request" do #, :vcr, record: :new_episodes do
      Sabre::Hotel.change_aaa(@session)
      hotels = Sabre::Hotel.find_by_geo(@session, (Date.today + 6.days), (Date.today+8.days),
        '40.0375','-107.9131',2,[],[],['THH','AVT','THW','THV','TRV'])
      hotels.should be_empty
    end

    it "should return a list of hotels given a valid availability request" do #, :vcr, record: :new_episodes do
      hotels = Sabre::Hotel.find_by_iata(@session,Time.now+172800, Time.now+432000,'DFW','1')
      hotels.first.latitude.should_not be_nil
      hotels.size.should > 0
    end

    it "should return a list of errors when an invalid lat/lng request is sent", :vcr, record: :new_episodes do
      expect { Sabre::Hotel.find_by_geo(@session, (Time.now+172800), (Time.now+432000),nil,nil,'1')}.to raise_error
    end

    # Works with 0040713
    # 0112273 is Best Western Denver
    it "should return a hotels description response", :vcr, record: :new_episodes do
      Sabre::Hotel.change_aaa(@session)
      hotel = Sabre::Hotel.profile(@session,'0016862',Time.now+172800, Time.now+432000, '1',['THH'])
      hotel.latitude.should_not be_nil
      hotel.cancellation.should_not be_nil
    end

    it "should return the rate details for a hotel", :vcr, record: :new_episodes do
      hotels = Sabre::Hotel.find_by_geo(@session, (Time.now+172800), (Time.now+432000),'39.75','-104.87','1')
      hotel = hotels.sample
      hotel = Sabre::Hotel.profile(@session,hotel.hotel_code,Time.now+172800, Time.now+432000, '1')
      rate = hotel.rates.sample
      rate[:nightly_prices].should_not be_empty
      room_stay, cancellation = Sabre::Hotel.rate_details(@session,rate[:line_number])
      cancellation.should_not be_nil
    end

    # This needs to be a Long booking
    it "should book a hotel reservation", :vcr, record: :new_episodes do
      check_in = Date.today + 25.days
      check_out = check_in + 2.days
      Sabre::Traveler.profile(@session, Faker::Name.first_name, Faker::Name.last_name, '303-861-9300')
      hotel = Sabre::Hotel.profile(@session,'0040713',check_in, check_out, '1')
      rate = hotel.rates.sample
      rates, cancellation = Sabre::Hotel.rate_details(@session,rate[:line_number])
      rate = rates.first
      booking = Sabre::Reservation.book(@session,rate[:line_number].to_i,'1','1','179.00','USD','TEST','AX','378282246310005',(Time.now + 6000000),'123')
      booking.to_hash.should include(:ota_hotel_res_rs)
      booking.to_hash[:ota_hotel_res_rs]
    end

    it "should fail booking a hotel reservation", :vcr, record: :new_episodes do
      check_in = Date.today + 25.days
      check_out = check_in + 2.days
      Sabre::Traveler.profile(@session, Faker::Name.first_name, Faker::Name.last_name, '303-861-9300')
      hotel = Sabre::Hotel.profile(@session,'0040713',check_in, check_out, '1')
      rate = hotel.rates.sample
      rates, cancellation = Sabre::Hotel.rate_details(@session,rate[:code])
      rate = rates.first
      res = Sabre::Reservation.book(@session,rate[:line_number].to_i,'1','2','179.00','USD','TEST','VI','4111',(Time.now + 6000000),'123').to_hash.should include(:ota_hotel_res_rs)
      res.should raise_exception
    end

    it "should cancel a hotel reservation", :vcr, record: :new_episodes do
      Sabre::Reservation.cancel_stay(@session)
    end

    after(:each) do
      @session.close
    end
  end

  context "Connection Pool" do
    before(:each) do
      Sabre.wsdl_url = 'http://webservices.sabre.com/wsdl/tpfc/' # 2.0
      Sabre.endpoint_url = 'https://webservices.sabre.com/websvc'
      Sabre.cert_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/usg/SessionCreateRQ.wsdl'
      Sabre.orig_wsdl_url = 'http://webservices.sabre.com/wsdl/sabreXML1.0.00/tpf/' # 1.0
      Sabre.ipcc = 'P40G'
      Sabre.pcc = 'N10G'
      Sabre.conversation_id = 'elia@mytravelershaven.com'
      Sabre.domain = 'hotelengine.com'
      Sabre.username = '7971'
      Sabre.password = 'WS020212'
      @pool = Sabre::ConnectionManager.new(:pool_size => 5)
    end

    it "should have a connection manager that initiate connections" do
      @pool.connections.size.should == 5
    end

    after(:each) do
      @pool.destroy_all
    end
  end
end
