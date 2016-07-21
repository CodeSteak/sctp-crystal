 class SCTPSocket < IPSocket

   class SCTPChannel
     getter stream_no : UInt16
     getter destination : IPAddress
     getter parent : SCTPSocket
     @in_channel : Channel::Buffered(Slice(UInt8))

     def initialize(@parent : SCTPSocket, sctp_stream_no : UInt16 | Int32,  @destination : IPAddress)
       @stream_no = sctp_stream_no.to_u16
       in_channel = Channel::Buffered(Slice(UInt8)).new
       @parent.register_stream_channel(in_channel, sctp_stream_no, @destination)
       @in_channel = in_channel
     end

     def send(data)
        @parent.send(data, @stream_no, @destination)
     end

     def receive : Slice(UInt8)
       @in_channel.receive
     end

     def receive_string : String
       String.new receive
     end

     def close
       @parent.unregister_stream_channel(@stream_no, @destination)
     end

   end

   @stream_channel = Hash({UInt16, IPAddress}, Channel::Buffered(Slice(UInt8))).new

   def register_stream_channel(channel : Channel::Buffered(Slice(UInt8)), stream_no : UInt16, source : IPAddress)
     @stream_channel[{stream_no, source}] = channel
   end

   def unregister_stream_channel(stream_no : UInt16, source : IPAddress)
     @stream_channel.delete({stream_no, source})
   end

   def [](stream_no : UInt16 | Int32, source : IPAddress)
     raise Error.new "Error opening SCTPChannel Object: it already exits" if @stream_channel[{stream_no, source}]?
     SCTPChannel.new(self, stream_no.to_u16, source)
   end

   def initialize(family : Socket::Family = Socket::Family::INET6)
      super create_socket(family.value, LibC::SOCK_SEQPACKET, LibC::IPPROTO_SCTP)
      enable_sctp_data_io_event
   end

   def initialize(fd : Int32)
     super fd
     enable_sctp_data_io_event
   end

   private def enable_sctp_data_io_event
     event = LibC::SctpEventSubscribe.new
     event.sctp_data_io_event = 1_u8
     LibC.setsockopt(@fd, LibC::IPPROTO_SCTP, LibC::SCTP_EVENTS, pointerof(event).as(Void*), sizeof(LibC::SctpEventSubscribe))
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
    loop do
      slice = Slice(UInt8).new 8196
      len, stream_no, address = receive(slice)

      if ch = @stream_channel[{stream_no, address}]?
        ch.send(slice[0, len])
      else
        return {slice[0, len], stream_no, address}
      end
    end
  end

  def receive(slice : Slice(UInt8)) : {Int32, UInt16, IPAddress}
    loop do
      sockaddr = uninitialized LibC::SockaddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      sndrcvinfo = uninitialized LibC::SctpSndrcvinfo
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

  def send(slice : Slice(UInt8), stream_no : UInt16, to : IPAddress) : Int32
    loop do
      sockaddr = to.sockaddr
      flags = 0
      #   fun sctp_sendmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, to : Sockaddr*, tolen : SocklenT, ppid : Uint32T, flags : Uint32T, stream_no : Uint16T, timetolive : Uint32T, context : Uint32T) : LibC::Int
      bytes_sent = LibC.sctp_sendmsg(@fd, slice.to_unsafe.as(Void*), slice.size, pointerof(sockaddr).as(LibC::Sockaddr*), to.addrlen, 0, flags, stream_no, 0, 0)
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

  def send(data, stream_no : Int32 | UInt16, to : IPAddress) : Int32
    io = MemoryIO.new
    io << data
    send(io.to_slice, stream_no.to_u16, to)
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
