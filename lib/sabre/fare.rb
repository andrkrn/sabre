module Sabre

  class Fare

    # attr_accessor

    LOG_TO_FILE = true

    def initialize(options)

    end


    def self.low_fare_search_round_trip(session, wsdl_url_root, origin, destination, args)
      request_wsdl    = 'OTA_AirLowFareSearchLLS2.3.0RQ.wsdl'
      request_method  = 'OTA_AirLowFareSearchRQ'
      request_version = '2.3.0'

      default_options = {
        max_stops: 9,
        passengers:  2,
        carrier_codes: []
      }

      options = default_options.merge(args)

      outbound_departs_at  = options[:outbound_departs_at]
      outbound_arrives_at  = options[:outbound_arrives_at]
      return_departs_at    = options[:return_departs_at]
      return_arrives_at    = options[:return_arrives_at]
      include_vendors      = options[:include_vendors]
      exclude_vendors      = options[:exclude_vendors]
      max_stops            = options[:max_stops]
      private_fares        = options[:private_fares]
      public_fares         = options[:public_fares]
      passenger_type_codes = options[:passenger_type_codes]
      adult_passengers     = options[:adults] || args[:passengers]
      child_passengers     = options[:children]
      infant_passengers    = options[:infants]
      carrier_codes        = options[:carrier_codes]


      has_outbound_date =  (outbound_departs_at || outbound_arrives_at)
      has_return_date   = (return_departs_at || return_arrives_at)


      raise SabreException::SearchError, 'No results found when missing outbound or return dates' unless has_outbound_date && has_return_date

      outbound_segment_attrs = {}
      # outbound_segment_attrs['ConnectionInd'] = "0" # Todo: Find out what this means
      outbound_segment_attrs['DepartureDateTime'] = outbound_departs_at.strftime('%Y-%m-%dT%H:%M:%S') if outbound_departs_at
      outbound_segment_attrs['ArrivalDateTime'] = outbound_arrives_at.strftime('%Y-%m-%dT%H:%M:%S') if outbound_arrives_at
      # outbound_segment_attrs['ResBookDesigCode'] = nil if 0 == 1

      return_segment_attrs = {}
      # return_segment_attrs['ConnectionInd'] = "0" # Todo: Find out what this means
      return_segment_attrs['DepartureDateTime'] = return_departs_at.strftime('%Y-%m-%dT%H:%M:%S') if return_departs_at
      return_segment_attrs['ArrivalDateTime'] = return_arrives_at.strftime('%Y-%m-%dT%H:%M:%S') if return_arrives_at
      # return_segment_attrs['ResBookDesigCode'] = nil if 0 == 1

      xml = Builder::XmlMarkup.new

      xml.OTA_AirLowFareSearchRQ('Version' => "2.3.0",
        'xmlns' => "http://webservices.sabre.com/sabreXML/2011/10",
        'xmlns:xs' => "http://www.w3.org/2001/XMLSchema",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance") do

        xml.OriginDestinationInformation('RPH' => "1") do
          xml.FlightSegment(outbound_segment_attrs) do
            xml.DestinationLocation('LocationCode' => destination)
            xml.OriginLocation('LocationCode' => origin)
          end
        end
        xml.OriginDestinationInformation('RPH' => "2") do
          xml.FlightSegment(return_segment_attrs) do
            xml.DestinationLocation('LocationCode' => origin)
            xml.OriginLocation('LocationCode' => destination)
          end
        end
        xml.PriceRequestInformation do
          xml.OptionalQualifiers do
            if carrier_codes.present?
              xml.FlightQualifiers('NumStops' => max_stops) do
                if carrier_codes.present?
                  xml.VendorPrefs('Exclude' => false) do
                    carrier_codes.each do |cc|
                      xml.Airline('Code' => cc)
                    end
                  end
                end
              end
            else
              xml.FlightQualifiers('NumStops' => max_stops) if max_stops
            end
            xml.PricingQualifiers('CurrencyCode' => 'USD') do
              xml.FareOptions('Private' => true) if private_fares == true
              xml.FareOptions('Public' => true) if public_fares == true
              # TODO : Add Support for Passenger Type Code
              # xml.PassengerType('Code' => 'JCB', 'Quantity' => adult_passengers)
              # if private_fares == true
              # xml.PassengerType('Code' => 'JCB', 'Quantity' => adult_passengers)
              # else
              xml.PassengerType('Code' => 'ADT', 'Quantity' => adult_passengers)
              # end
            end
          end
        end
      end


      namespaces = {
       "xmlns:soap-env" => "http://schemas.xmlsoap.org/soap/envelope/",
       "xmlns:eb" => "http://www.ebxml.org/namespaces/messageHeader",
       "xmlns:xlink" => "http://www.w3.org/1999/xlink"
     }

     Rails.logger.info("SEND AIR TO SABRE (#{Time.now()})")

      client = Savon.client do
        convert_request_keys_to(:camelcase)
        wsdl(wsdl_url_root + 'OTA_AirLowFareSearchLLS2.3.0RQ.wsdl')
        env_namespace("soap-env")
        soap_header(session.header('OTA_AirLowFareSearchRQ','OTA','OTA_AirLowFareSearchLLSRQ'))
        namespaces(namespaces)
      end
      response = client.call(:ota_air_low_fare_search_rq) do
        message(xml.target!)
      end

      Rails.logger.info("SENT AIR TO SABRE (#{Time.now()})")

      

      if LOG_TO_FILE &&  Sabre.tmp_directory.present?
        filename = "#{origin}-#{destination}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
        File.open("#{Sabre.tmp_directory}/#{filename}.xml", 'w') {|f| f.write(response.to_xml) }
        # File.open("#{Sabre.tmp_directory}/#{filename}.rb", 'w') {|f| f.write(response.to_hash[:ota_air_low_fare_search_rs]) }
      end

      return response.to_xml
    end



    private


    # PricedItinerary [0..*]
    def self.itinerary(response)

    end

    # PricedItinerary > AirItineraryPricingInfo [0..*]
    def self.itinerary_pricing_info(response)

    end

    # AirItineraryPricingInfo > ItinTotalFare [0..1]
    def self.itinerary_total_fare(response)

    end

    # ItinTotalFare > BaseFare [0..1]
    def self.base_fare(response)

    end

    # ItinTotalFare > Commission [0..1]
    def self.commission(response)

    end

    # ItinTotalFare > EquivFare [0..1]
    def self.equiv_fare(response)

    end

    # ItinTotalFare > TotalFare [0..1]
    def self.total_fare(response)

    end

    # ItinTotalFare > Taxes > Tax [0..*]
    def self.tax_item(response)

    end

    # ItinTotalFare > Warnings > Warning [0..*]
    def self.warning(response)

    end

    # AirItineraryPricingInfo > PassengerTypeQuantity [0..1]
    def self.passenger_type_quantity(response)

    end

    # AirItineraryPricingInfo > PTC_FareBreakdown [0..*]
    def self.fare_breakdown(response)

    end

    # PTC_FareBreakdown > FareBasis [0..1]
    def self.fare_basis(response)

    end

    # PTC_FareBreakdown > Surcharges [0..*]
    def self.surcharges(response)

    end

    # PricedItinerary > HeaderInformation [0..1]
    def self.header_information(response)

    end

    # PricedItinerary > OriginDestinationOption [0..*]
    def self.origin_destination_option(response)

    end

    # OriginDestinationOption > FlightSegment [0..*]

    def self.flight_segment(response)
      # segment = response[:origin_destination_option][:flight_segment]
      # ArrivalDateTime
      # ConnectionInd
      # DepartureDateTime
      # DestinationTimeZone
      # DivideInd
      # ElapsedTime
      # eTicket
      # FlightNumber
      # MarketingCabin
      # OnTimeRate
      # OnTimePercent
      # OriginTimeZone
      # ResBookDesigCode
      # RPH
      # SmokingAllowed
      # StopQuantity

    end

    # FlightSegment > IntermediatePointInfo [0..1]
    def self.intermediate_point_info(response)
      # NOTE: This appears to be used for sub-segments, Havent seen an actual use case
    end

  end

  # PricedItinerary [0..*]
  class Itinerary
    attr_reader :pricing_infos, :header_info, :origin_destination_options, :currency_code,
                :customize_routing_option, :rph, :total_amount

    def initialize(args)
      if args[:response]
        # Parse Response Hash into Itinerary Object
      else
        @pricing_infos = args[:pricing_infos]
        @header_info = args[:header_info]
        @origin_destination_options = args[:origin_destination_options]
        @currency_code = args[:currency_code]
        @customize_routing_option = args[:customize_routing_option]
        @rph = args[:rph]
        @total_amount = args[:total_amount]
      end

      # puts "********************************"
      # puts "****     ITINERARY RESP     ****"
      # puts "********************************"
      # puts self.to_yaml
      # puts "********************************"
      # puts "********************************"

    end
  end

  class OriginDestinationOption
    attr_reader :flight_segments, :rph

    def initialize(args)
      if args[:xml]
        # Parse XML into FlightSegment Object
      else
        @flight_segments = args[:flight_segments]
        @rph = args[:rph]
      end
    end
  end


  class FlightSegment
    attr_reader :arrival_date_time, :connection_ind, :departure_date_time, :destination_time_zone,
    :divide_ind, :elapsed_time, :e_ticket, :flight_number, :marketing_cabin,
    :on_time_rate, :on_time_percent, :origin_time_zone, :res_book_desig_code, :rph,
    :smoking_allowed, :stop_quantity, :intermediate_point_info

    def initialize(args)
      if args[:xml]
        # Parse XML into FlightSegment Object
      else
        @arrival_date_time = args[:arrival_date_time]
        @connection_ind = args[:connection_ind]
        @departure_date_time = args[:departure_date_time]
        @destination_time_zone = args[:destination_time_zone]
        @divide_ind = args[:divide_ind]
        @elapsed_time = args[:elapsed_time]
        @e_ticket = args[:e_ticket]
        @flight_number = args[:flight_number]
        @marketing_cabin = args[:marketing_cabin]
        @on_time_rate = args[:on_time_rate]
        @on_time_percent = args[:on_time_percent]
        @origin_time_zone = args[:origin_time_zone]
        @res_book_desig_code = args[:res_book_desig_code]
        @rph = args[:rph]
        @smoking_allowed = args[:smoking_allowed]
        @stop_quantity = args[:stop_quantity]
        @intermediate_point_info = args[:intermediate_point_info]
      end
    end
  end

end
