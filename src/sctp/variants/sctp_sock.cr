require "../sctp_base_socket"

class SCTPSocket < SCTPBaseSocket
  def initialize(family : Socket::Family = Socket::Family::INET6)
    super family, Socket::Type::SEQPACKET
    enable_sctp_events
  end
end
