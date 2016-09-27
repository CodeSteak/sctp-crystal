require "../sctp_base_socket"

class SCTPStreamServer < SCTPBaseSocket
  def initialize(host, port, backlog = 128)
    bind(host, port, Socket::Type::STREAM) do |addrinfo|
      super create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol), Socket::Type::SEQPACKET
    end
    listen(backlog)
  end

  def self.new(port : Int, backlog = 128)
    new("::", port, backlog)
  end

  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def accept?
    sock = accept?
    return unless sock

    begin
      yield sock
    ensure
      sock.close
    end
  end

  def accept : SCTPStreamSocket
    accept? || raise IO::Error.new("closed stream")
  end

  def accept? : SCTPStreamSocket?
    loop do
      client_addr = uninitialized LibC::SockaddrIn6
      client_addr_len = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))
      client_fd = LibC.accept(fd, pointerof(client_addr).as(LibC::Sockaddr*), pointerof(client_addr_len))
      if client_fd == -1
        return nil if closed?

        if Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new "Error accepting socket"
        end
      else
        sock = SCTPStreamSocket.new(client_fd)
        sock.sync = sync?
        return sock
      end
    end
  end
end
