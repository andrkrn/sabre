require 'yaml'
require 'savon'

module Sabre
  class Session
    attr_accessor :username, :password, :pcc, :ipcc, :binary_security_token, :ref_message_id, :domain, :conversation_id
    def initialize(conversation_id)
      @username = Sabre.username
      @password = Sabre.password
      @ipcc = Sabre.ipcc
      @domain = Sabre.domain
      @pcc = Sabre.pcc
      @conversation_id = conversation_id
      #@conversation_id = conversation_id

      #@client = Savon::Client.new(wsdl: config[Rails.env]['wsdl_url'])
      open
    end

    def open
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

      @binary_security_token = response.xpath("//wsse:BinarySecurityToken")[0].content
      @ref_message_id = response.xpath("//eb:RefToMessageId")[0].content
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
        #soap.body = {
        #  'EchoData' => 'Ping'
        #}
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

    # def close
    #   client = Savon::Client.new(wsdl: Sabre.cert_wsdl_url.gsub('SessionCreate','SessionClose'))
    #   client.call(:session_close_rq) do
    #     Sabre.soap_namespaces(soap)
    #     soap.header = header('Session','sabreXML','SessionCloseRQ')
    #     soap.body = { 'POS' => { 'Source' => "", :attributes! => { 'Source' => { 'PseudoCityCode' => self.ipcc } } } }
    #   end
    # end

    # def header(service, type, action, version = '2.0')

    #   @xml = Nokogiri::XML::DocumentFragment.parse ""
    #   Nokogiri::XML::Builder.with(@xml) do |xml|
    #     xml.Root("xmlns:eb"   => "http://www.acme.com","xmlns:wsse" => "http://www.acme.com") do 
    #       xml['eb'].MessageHeader('eb:version' => version, 'soap-env:mustUnderstand' => '1') do
    #         xml['eb'].ConversationId(){ xml.text(self.conversation_id) }
    #         xml['eb'].From() do
    #           xml['eb'].PartyId('type' => 'urn:x12.org:IO5:01'){ xml.text(self.domain) }
    #         end
    #         xml['eb'].To() do
    #           xml['eb'].PartyId('type' => 'urn:x12.org:IO5:01'){ xml.text('webservices.sabre.com') }
    #         end
    #         xml['eb'].CPAId(){ xml.text(self.ipcc) }
    #         xml['eb'].Service('eb:type' => type)
    #         xml['eb'].Action(){ xml.text(action) }
    #         xml['eb'].MessageData() do
    #           xml['eb'].MessageId(){ xml.text("mid:#{Time.now.strftime('%Y%m%d-%H%M%S')}@#{self.domain}") }
    #           xml['eb'].RefToMessageId(){ xml.text(self.ref_message_id) }
    #           xml['eb'].Timestamp(){ xml.text(Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')) }
    #         end
    #         xml['wsse'].Security('xmlns:wsse' => 'http://schemas.xmlsoap.org/ws/2002/12/secext') do
    #           xml['wsse'].BinarySecurityToken('xmlns:wsu' => 'http://schemas.xmlsoap.org/ws/2002/12/utility', 'wsu:Id' => 'SabreSecurityToken', 'valueType' => 'String', 'EncodingType' => 'wsse:Base64Binary'){ xml.text(self.binary_security_token) }
    #         end
    #       end
    #     end
    #   end
    #   return @xml.to_xml
    # end

    def header(service, type, action, version = '2.0')
        msg_header = { 'eb:ConversationId' => self.conversation_id,
                  'eb:From' => { 'eb:PartyId' => self.domain, 
                    :attributes! => { 'eb:PartyId' => { 'type' => 'urn:x12.org:IO5:01' } } },
                  'eb:To' => { 'eb:PartyId' => "webservices.sabre.com", 
                    :attributes! => { 'eb:PartyId' => { 'type' => 'urn:x12.org:IO5:01' } } },
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
