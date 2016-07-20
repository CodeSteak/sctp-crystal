 class SCTPSocket < IPSocket

   def initialize(family : Socket::Family = Socket::Family::INET6)
      super create_socket(family.value, LibC::SOCK_SEQPACKET, LibC::IPPROTO_SCTP)
   end

   def initialize(fd : Int32)
     super fd
   end

   def bind(host, port, dns_timeout = nil)
     getaddrinfo(host, port, nil, LibC::SOCK_SEQPACKET, LibC::IPPROTO_SCTP, timeout: dns_timeout) do |addrinfo|
       self.reuse_address = true

       ret = LibC.bind(@fd, addrinfo.ai_addr, addrinfo.ai_addrlen)

       unless ret == 0
         next false if addrinfo.ai_next
         raise Errno.new("Error binding SCTPSocket socket at #{host}:#{port}")
       end
       true
     end
   end

   def listen(backlog = 128)
     if LibC.listen(@fd, backlog) != 0
       errno = Errno.new("Error listening SCTPSocket")
       close
       raise errno
     end
   end

  def receive : {Slice(UInt8), UInt16, IPAddress}
    slice = Slice(UInt8).new 8196
    len, stream_no, address = receive(slice)
    {slice[0, len], stream_no, address}
  end

  def receive(slice : Slice(UInt8)) : {Int32, UInt16, IPAddress}
    loop do
      sockaddr = uninitialized LibC::SockaddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      sndrcvinfo = LibC::SctpSndrcvinfo.new
      flags = 0

      #  fun sctp_recvmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, from : Sockaddr*, fromlen : SocklenT*, sinfo : SctpSndrcvinfo*, msg_flags : LibC::Int*) : LibC::Int
      bytes_read = LibC.sctp_recvmsg(@fd, (slice.to_unsafe.as(Void*)), slice.size, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen), pointerof(sndrcvinfo), pointerof(flags))
      if bytes_read != -1
        return {
          bytes_read.to_i32,
          sndrcvinfo.sinfo_stream,
          IPAddress.new(sockaddr, addrlen),
        }
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new("Error receiving datagram")
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  def send(stream_no : Int32 | UInt16, addr : IPAddress, data) : Int32
    io = MemoryIO.new
    io << data
    send(io.to_slice, stream_no.to_u16, addr)
  end

  def send(slice : Slice(UInt8), stream_no : UInt16, addr : IPAddress) : Int32
    loop do
      sockaddr = addr.sockaddr
      flags = 0
      #   fun sctp_sendmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, to : Sockaddr*, tolen : SocklenT, ppid : Uint32T, flags : Uint32T, stream_no : Uint16T, timetolive : Uint32T, context : Uint32T) : LibC::Int
      bytes_sent = LibC.sctp_sendmsg(@fd, slice.to_unsafe.as(Void*), slice.size, pointerof(sockaddr).as(LibC::Sockaddr*), addr.addrlen, 0, flags, stream_no, 0, 0)
      if bytes_sent != -1
        return bytes_sent
      end

      if Errno.value == Errno::EAGAIN
        wait_writable
        next
      elsif Errno.value == Errno::EBADF
        raise IO::Error.new "Socket not open for writing"
      else
        raise Errno.new "Error sending data on SCTPSocket"
      end
    end
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  def addressv4(host, port)
    IPAddress.new Socket::Family::INET, host, port
  end

  def addressv6(host, port)
    IPAddress.new Socket::Family::INET6, host, port
  end

  def address(host, port, family = Socket::Family::INET6)
    IPAddress.new family, host, port
  end

 end
