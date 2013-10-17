begin
  module Sabre
    class Connection
      attr_accessor :session, :security_token, :conversation_id, :status, :client_id, :created_at, :updated_at

      def initialize(*h)
        if h.length == 1 && h.first.kind_of?(Hash)
          h.first.each { |k,v| send("#{k}=",v) }
        end

        self.session = Sabre::Session.new(self.conversation_id)
        self.created_at = DateTime.now
        self.session.open
      end

      def identity

      end

      def clear
        client = Sabre.client('IgnoreTransactionLLS2.0.0RQ.wsdl')
        response = client.request('IgnoreTransactionRQ', Sabre.request_header('2.0.0','skip')) do
          Sabre.namespaces(soap)
          soap.header = self.session.header('IgnoreTransactionLLSRQ','sabreXML','IgnoreTransactionLLSRQ')
        end
        self.updated_at = DateTime.now
        response.to_hash[:ignore_transaction_rs]
      end

      def release
        self.status = 'available'
        self.updated_at = DateTime.now
      end

      def destroy
        self.session.close
        puts "Destroyed session #{self.session}"
      end
    end
  end
end
