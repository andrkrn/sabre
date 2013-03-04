module Sabre
  class Connection
    attr_accessor :session, :security_token, :conversation_id, :status, :client_id, :created_at, :updated_at

    def initialize(*h)
      if h.length == 1 && h.first.kind_of?(Hash)
        h.first.each { |k,v| send("#{k}=",v) }
      end

      self.session = Sabre::Session.new(self.conversation_id)
      self.session.open
    end

    def destroy
      self.session.close
      puts "Destroyed session #{self.session}"
    end
  end
end
