module Sabre
  class Context

    def initialize(options)

    end


    def self.change_pcc(session, pcc)
      request_wsdl    = 'ContextChangeLLS2.0.3RQ.wsdl'
      request_method  = 'ContextChangeRQ'
      request_version = '2.0.3'

      xml = Builder::XmlMarkup.new

      xml.ContextChangeRQ('Version' => "2.0.3",
        'xmlns' => "http://webservices.sabre.com/sabreXML/2011/10",
        'xmlns:xs' => "http://www.w3.org/2001/XMLSchema",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance") do
        xml.ChangeAAA('PseudoCityCode' => pcc)
      end

      namespaces = {
       "xmlns:soap-env" => "http://schemas.xmlsoap.org/soap/envelope/",
       "xmlns:eb" => "http://www.ebxml.org/namespaces/messageHeader",
       "xmlns:xlink" => "http://www.w3.org/1999/xlink"
     }

      client = Savon.client do
        convert_request_keys_to(:camelcase)
        wsdl(Sabre.wsdl_url + 'ContextChangeLLS2.0.3RQ.wsdl')
        env_namespace("soap-env")
        soap_header(session.header('ContextChangeRQ','sabreXML','ContextChangeLLSRQ'))
        namespaces(namespaces)
      end

      response = client.call(:context_change_rq) do
        message(xml.target!)
      end

      filename = "context-change-#{pcc}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"

      unless Sabre.tmp_directory.blank?
        File.open("#{Sabre.tmp_directory}/#{filename}.xml", 'w') {|f| f.write(response.to_xml) }
        File.open("#{Sabre.tmp_directory}/#{filename}.rb", 'w') {|f| f.write(response.to_hash[:context_change_rs]) }
      end

      return response.to_xml
    end



  end


end
