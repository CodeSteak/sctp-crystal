require "../sctp_base_socket"

class SCTPServer < SCTPBaseSocket
  def initialize(host, port, backlog = 128)
    bind(host, port, Socket::Type::SEQPACKET) do |addrinfo|
      super create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol), Socket::Type::SEQPACKET
    end

    listen(backlog)
  end
end
