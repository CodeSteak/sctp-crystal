require "./sctp_stream_socket"

class SCTPStreamServer < SCTPStreamSocket
  def initialize(host, port, backlog = 128)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_SCTP) do |addrinfo|
      sock = create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol)
      super sock

      self.reuse_address = true

      if LibC.bind(sock, addrinfo.ai_addr.as(LibC::Sockaddr*), addrinfo.ai_addrlen) != 0
        errno = Errno.new("Error binding SCTP server at #{host}:#{port}")
        LibC.close(sock)
        next false if addrinfo.ai_next
        raise errno
      end

      if LibC.listen(sock, backlog) != 0
        errno = Errno.new("Error listening SCTP server at #{host}:#{port}")
        LibC.close(sock)
        next false if addrinfo.ai_next
        raise errno
      end

      true
    end
  end

  def self.new(port : Int, backlog = 128)
    new("::", port, backlog)
  end

  def self.open(host, port, backlog = 128)
    server = new(host, port, backlog)
    begin
      yield server
    ensure
      server.close
    end
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
