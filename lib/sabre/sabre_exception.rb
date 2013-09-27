module SabreException
  class ReservationError < StandardError; end
  class ConnectionError < StandardError; end
  class SearchError < StandardError; end
  class CancelError < StandardError; end
end
