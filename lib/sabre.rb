require 'active_support/all'
require 'sabre/version'
require 'yaml'
require 'savon'
require 'sabre/session'
require 'sabre/traveler'
require 'sabre/hotel'
require 'sabre/reservation'
require 'sabre/sabre_exception'

module Sabre
  mattr_accessor :cert_wsdl_url, :wsdl_url, :endpoint_url, :username, :password, :ipcc, :pcc, :account_email, :domain, :binary_security_token, :ref_message_id

  def self.connect(&block)
    @errors = []
    begin
      session = Session.new
      session.open
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

  def self.client(service)
    client = Savon::Client.new(self.wsdl_url+service)
    client.http.headers["Content-Type"] = "text/xml;charset=UTF-8"
    return client
  end

  def self.request_header(version, timestamp = true)
#    if timestamp
      { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10', 
        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 
        'ReturnHostCommand' => 'true',
        'TimeStamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S'), 
        'Version' => version 
      }
#    else
#      { 'xmlns' => 'http://webservices.sabre.com/sabreXML/2011/10', 
#        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema', 
#        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 
#        'Version' => version 
#      }
#    end
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

  def self.namespaces(soap)
    soap.namespaces["xmlns:SOAP-ENV"] = "http://schemas.xmlsoap.org/soap/envelope/"
    soap.namespaces["xmlns:eb"] = "http://www.ebxml.org/namespaces/messageHeader"
    soap.namespaces["xmlns:xlinx"] = "http://www.w3.org/1999/xlink"
    soap.version = 1
    return soap
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
