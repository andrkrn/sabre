require 'active_support/all'
require 'sabre/version'
require 'yaml'
require 'savon'
require 'sabre/connection'
require 'sabre/connection_manager'
require 'sabre/session'
require 'sabre/context'
require 'sabre/traveler'
require 'sabre/hotel'
require 'sabre/fare'
require 'sabre/reservation'
require 'sabre/sabre_exception'

module Sabre
  mattr_accessor :cert_wsdl_url, :wsdl_url, :usg_wsdl_url, :orig_wsdl_url, :endpoint_url,
                 :username, :password, :ipcc, :pcc, :conversation_id, :domain,
                 :binary_security_token, :ref_message_id, :tmp_directory

  def self.connect(&block)
    @errors = []
    begin
      session = Session.new(self.conversation_id)
      block.call(session)
    #rescue SabreException::ConnectionError => e
    #  @errors << {:type => e.class.name, :message => Sabre.clean_error_message(e.message)}
    #rescue SabreException::ReservationError => e
    #  @errors << {:type => e.class.name, :message => Sabre.clean_error_message(e.message)}
    #rescue SabreException::SearchError => e
    #  @errors << {:type => e.class.name, :message => Sabre.clean_error_message(e.message)}
    rescue Timeout::Error => e
      @errors << {:type => e.class.name, :message => "Sabre Travel Network service request failed due to timeout"}
    ensure
      session.close
    end
    return @errors if @errors.any?
  end

  def self.client(service, version = 2, args = {})

    wsdl = case version
      when 0 then [self.usg_wsdl_url,service].join("")
      when 1 then self.orig_wsdl_url + service
      else self.wsdl_url + service
    end

    default_options = {
      wsdl: wsdl,
      headers: { "Content-Type" => "text/xml;charset=UTF-8" }
    }
    options = default_options.merge(args)

    client = Savon::Client.new(options)

    return client
  end

  def self.request_namespaces
   {
     'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10',
     'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
     'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
   }
  end

  def self.request_header(version, skip_return_host = false)
#    if timestamp
    if skip_return_host
      { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10',
        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'Version' => version
      }
    else
      { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10',
        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'ReturnHostCommand' => 'true',
        'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
        'Version' => version
      }
    end
#    else
#      { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10',
#        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
#        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
#        'Version' => version
#      }
#    end
  end

  def self.request_ping_header(version)
    { 'xmlns' => 'http://www.opentravel.org/OTA/2003/05',
      'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
      'Version' => version
    }
  end

  def self.request_old_header(version, timestamp = true)
    { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2003/07',
      'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
      'Version' => version
    }
  end

  def self.setup
    yield self
  end

  def self.pos
    { 'Source' => "", :attributes! => { 'Source' => { 'PseudoCityCode' => self.ipcc } } }
  end

  def self.soap_namespaces(soap)
    soap.namespaces["xmlns:soap-env"] = "http://schemas.xmlsoap.org/soap/envelope/"
    soap.namespaces["xmlns:eb"] = "http://www.ebxml.org/namespaces/messageHeader"
    soap.namespaces["xmlns:xlinx"] = "http://www.w3.org/1999/xlink"
    soap.version = 1
    return soap
  end

  def self.namespaces
   {
     "xmlns:soap-env" => "http://schemas.xmlsoap.org/soap/envelope/",
     "xmlns:eb" => "http://www.ebxml.org/namespaces/messageHeader",
     "xmlns:xlinx" => "http://www.w3.org/1999/xlink"
   }
  end

  def self.error_message(msg)
    msg = "#{msg[:application_results][:error][:system_specific_results][:host_command]}: #{msg[:application_results][:error][:system_specific_results][:message]}: #{msg[:application_results][:error][:system_specific_results][:short_text]}"
    return clean_error_message(msg)
  end

  def self.clean_error_message(msg)
    msg = 'Invalid Card Number' if msg.include?('INVALID CARD NUMBER')
    msg = 'Invalid Expiration Date' if msg.include?('INVALID EXP DATE')
    msg = 'Invalid Format' if msg.include?('INVALID FORMAT')
    return msg
  end

end
