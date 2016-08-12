require "./sctp_socket"

class SCTPServer < SCTPSocket
  def initialize(host, port, backlog = 128)
    super()
    bind(host, port)
    listen(backlog)
  end
end
