require "../sctp_base_socket"

class SCTPStreamSocket < SCTPBaseSocket
  def initialize(fd : Int32)
    super fd, Socket::Type::STREAM
  end

  def initialize(host, port, dns_timeout = nil, connect_timeout = nil)
    connect(host, port, Socket::Type::STREAM) do |addrinfo|
      super create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol), Socket::Type::SEQPACKET
    end
  end

  def connect(host, port, type : Socket::Type, dns_timeout = nil, connect_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_SCTP, timeout: dns_timeout) do |addrinfo|
      yield addrinfo
      if err = nonblocking_connect host, port, addrinfo, timeout: connect_timeout
        close
        next false if addrinfo.ai_next
        raise err
      end
      true
    end
  end

  def send(slice : Slice(UInt8), stream_no : UInt16 | Int32 = 0) : Int32
    loop do
      flags = 0
      #   fun sctp_sendmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, to : Sockaddr*, tolen : SocklenT, ppid : Uint32T, flags : Uint32T, stream_no : Uint16T, timetolive : Uint32T, context : Uint32T) : LibC::Int
      bytes_sent = LibC.sctp_sendmsg(@fd, slice.to_unsafe.as(Void*), slice.size, Pointer(LibC::Sockaddr).null, 0, 0, flags, stream_no.to_u16, 0, 0)

      if bytes_sent != -1
        return bytes_sent
      end

      if Errno.value == Errno::EAGAIN
        wait_writable
        next
      elsif Errno.value == Errno::EBADF
        raise IO::Error.new "Socket not open for writing"
      else
        raise Errno.new "Error sending data on SCTPStreamSocket"
      end
    end
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  def send(data, stream_no : Int32 | UInt16) : Int32
    io = MemoryIO.new
    io << data
    send(io.to_slice, stream_no.to_u16)
  end
end
