begin
  module Sabre
    class ConnectionManager
      attr_accessor :pool_size, :connections

      def initialize(*h)
        if h.length == 1 && h.first.kind_of?(Hash)
          h.first.each { |k,v| send("#{k}=",v) }
        end
        destroy_all
        build_pool
      end

      def resource
        connection = self.connections.select{|c|c.status == 'available'}.sample
        connection.status = 'busy'
        connection.clear
        return connection
      end

      def refresh
        connection = self.connections.each{|c|c.session.validate if c.status = 'available'}
      end

      def destroy_all
        if self.connections
          self.connections.each{|c|c.destroy} 
        end
      end

      private
      def build_pool
        self.connections = []
        self.pool_size.times do
          self.connections << Connection.new(conversation_id: "hotelengine-#{Time.now.to_i}", status: 'available')
        end
      end
    end
  end
end
