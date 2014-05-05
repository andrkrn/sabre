require 'yaml'
require 'savon'

module Sabre
  class Session
    attr_accessor :username, :password, :pcc, :ipcc, :binary_security_token, :ref_message_id, :domain, :conversation_id

    def initialize(params)
      self.conversation_id       = params[:conversation_id]
      self.username              = params[:username] || Sabre.username
      self.password              = params[:password] || Sabre.password
      self.ipcc                  = params[:ipcc]     || Sabre.ipcc
      self.domain                = params[:domain]   || Sabre.domain
      self.pcc                   = params[:pcc]      || Sabre.pcc
      @is_open                   = params[:is_open]  || false
      self.binary_security_token = params[:binary_security_token]
      self.ref_message_id        = params[:ref_message_id]

      #@client = Savon::Client.new(wsdl: config[Rails.env]['wsdl_url'])
      # open
      # open unless (@is_open == true || (params[:auto_open] == false))
    end

    # def initialize(conversation_id)
    #   @username = Sabre.username
    #   @password = Sabre.password
    #   @ipcc = Sabre.ipcc
    #   @domain = Sabre.domain
    #   @pcc = Sabre.pcc
    #   @conversation_id = conversation_id
    #   #@conversation_id = conversation_id

    #   #@client = Savon::Client.new(wsdl: config[Rails.env]['wsdl_url'])
    #   open
    # end

    def open?
      return @is_open
    end

    def open
      return self if self.open?

      client = Savon::Client.new({
        wsdl: Sabre.cert_wsdl_url,
        soap_header: header('Session','sabreXML','SessionCreateRQ'),
        env_namespace: "soap-env",
        namespaces: Sabre.namespaces
      })

      # puts "*************************"
      # puts "*****  Savon Client  ****"
      # puts "*************************"
      # puts client.to_yaml
      # puts "*************************"
      # puts "*************************"

      message = { 'POS' => { 'Source' => "", :attributes! => { 'Source' => { 'PseudoCityCode' => self.ipcc } } } }

      response = client.call(:session_create_rq, message: message)

      self.binary_security_token = response.xpath("//wsse:BinarySecurityToken")[0].content
      self.ref_message_id = response.xpath("//eb:RefToMessageId")[0].content

      @is_open = true unless self.binary_security_token.blank?
    end

    def validate
      client = Savon::Client.new(wsdl: Sabre.cert_wsdl_url)
      response = client.call(:session_validate_rq) do
        Sabre.namespaces(soap)
        soap.header = header('Session','sabreXML','SessionValidateRQ')
        message = { 'POS' => { 'Source' => "", :attributes! => { 'Source' => { 'PseudoCityCode' => self.ipcc } } } }
      end
    end

    def ping
      client = Sabre.client('OTA_PingRQ.wsdl',0)
      response = client.call('OTA_PingRQ', Sabre.request_ping_header('1.0.0')) do
        Sabre.namespaces(soap)
        soap.header = header('OTA_PingRQ','sabreXML','OTA_PingRQ', '1.0')
        soap.body = {
          'EchoData' => 'Ping'
        }
      end
      response.to_hash
    end

    def clear
      client = Sabre.client('IgnoreTransactionLLS2.0.0RQ.wsdl')
      response = client.call('IgnoreTransactionRQ', Sabre.request_header('2.0.0',true)) do
        Sabre.namespaces(soap)
        soap.header = header('IgnoreTransactionLLSRQ','sabreXML', 'IgnoreTransactionLLSRQ')
      end
      response.to_hash
    end


    def close
      client = Savon::Client.new({
        wsdl: Sabre.cert_wsdl_url.gsub('SessionCreate','SessionClose'),
        soap_header: header('Session','sabreXML','SessionCloseRQ'),
        env_namespace: "soap-env",
        namespaces: Sabre.namespaces
      })
      message = { 'POS' => { 'Source' => "", :attributes! => { 'Source' => { 'PseudoCityCode' => self.ipcc } } } }
      client.call(:session_close_rq, message: message)
    end


    def header(service, type, action, version = '2.0')
        msg_header = {
          'eb:ConversationId' => self.conversation_id,
          'eb:From' => { 'eb:PartyId' => self.domain, :attributes! => { 'eb:PartyId' => { 'type' => 'urn:x12.org:IO5:01' } } },
          'eb:To' => { 'eb:PartyId' => "webservices.sabre.com", :attributes! => { 'eb:PartyId' => { 'type' => 'urn:x12.org:IO5:01' } } },
          'eb:CPAId' => self.ipcc,
          'eb:Service' => service, :attributes! => { 'eb:Service' => { 'eb:type' => type } },
          'eb:Action' => action,
          'eb:MessageData' => {
             'eb:MessageId' => "mid:#{Time.now.strftime('%Y%m%d-%H%M%S')}@#{self.domain}",
             'eb:RefToMessageId' => self.ref_message_id,
             'eb:Timestamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')#,
             #'eb:Timeout' => 300
          } }
      { 'eb:MessageHeader' => msg_header.to_hash,
        'wsse:Security' => security.to_hash, :attributes! => { 'wsse:Security' => { 'xmlns:wsse' => "http://schemas.xmlsoap.org/ws/2002/12/secext" }, 'eb:MessageHeader' => { 'soap-env:mustUnderstand' => "1", 'eb:version' => version } }
      }
    end

    def security
      if self.binary_security_token
        { 'wsse:BinarySecurityToken' => self.binary_security_token, :attributes! => { 'wsse:BinarySecurityToken' => { 'xmlns:wsu' => "http://schemas.xmlsoap.org/ws/2002/12/utility", 'wsu:Id' => 'SabreSecurityToken', 'valueType' => 'String', 'EncodingType' => "wsse:Base64Binary" } } }
      else
        { 'wsse:UsernameToken' => { 'wsse:Username' => self.username, 'wsse:Password' => self.password, 'Organization' => self.ipcc, 'Domain' => 'DEFAULT' } }
      end
    end

  end
end
