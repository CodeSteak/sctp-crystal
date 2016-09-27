class SCTPBaseSocket < IPSocket
  @processing = false

  def initialize(family : Socket::Family, @type : Socket::Type)
    super create_socket(family.value, @type.value, LibC::IPPROTO_SCTP)
    enable_sctp_events
  end

  def initialize(fd : Int32, @type : Socket::Type)
    super fd
    enable_sctp_events
  end

  @handler = Hash({UInt16?, IPAddress?}, (SCTPMessage ->)).new

  def on_message(&@on_message : SCTPMessage ->)
    unless @processing
      @processing = true
      spawn do
        process
      end
    end
  end

  def on_message(source : IPAddress, &callback : SCTPMessage ->)
    @handler[{nil, source}] = callback
  end

  def on_message(source : IPAddress, none : Nil)
    @handler.delete({nil, source})
  end

  def on_message(stream_no : UInt16 | Int32, &callback : SCTPMessage ->)
    @handler[{stream_no.to_u16, nil}] = callback
  end

  def on_message(stream_no : UInt16 | Int32, none : Nil)
    @handler.delete({stream_no.to_u16, nil})
  end

  def on_message(stream_no : UInt16 | Int32, source : IPAddress, &callback : SCTPMessage ->)
    @handler[{stream_no.to_u16, source}] = callback
  end

  def on_message(stream_no : UInt16 | Int32, source : IPAddress, none : Nil)
    @handler.delete({stream_no.to_u16, source})
  end

  def bind(host, port, type : Socket::Type, dns_timeout = nil)
    getaddrinfo(host, port, nil, type.value, LibC::IPPROTO_SCTP, timeout: dns_timeout) do |addrinfo|
      yield addrinfo
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

  def process
    @processing = true
    while !closed?
      msg = receive

      if ch = @handler[{msg.stream_no, msg.address}]?
        ch.call(msg)
      elsif ch = @handler[{nil, msg.address}]?
        ch.call(msg)
      elsif ch = @handler[{msg.stream_no, nil}]?
        ch.call(msg)
      else
        if calb = @on_message
          calb.call(msg)
        end
      end
    end
  rescue ex
    raise ex unless closed?
  end

  def receive : SCTPMessage
    loop do
      slice = Slice(UInt8).new 8196
      len, stream_no, address = receive(slice)
      return SCTPMessage.new slice[0, len], stream_no, address, self
    end
  end

  def receive(slice : Slice(UInt8)) : {Int32, UInt16, IPAddress}
    loop do
      check_open
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
        raise Errno.new("Error receiving SCTP message")
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  def send(slice : Slice(UInt8), stream_no : UInt16, to : IPAddress) : Int32
    check_open
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

  private def enable_sctp_events
    event = LibC::SctpEventSubscribe.new
    event.sctp_data_io_event = 1_u8
    # event.sctp_shutdown_event = 1_u8 TODO
    set_socketopt(LibC::SCTP_EVENTS, event)
  end

  def autoclose=(seconds : Int32?)
    set_socketopt(LibC::SCTP_AUTOCLOSE, seconds ? seconds : 0)
  end

  def set_socketopt(option : Int32, value)
    LibC.setsockopt(@fd, LibC::IPPROTO_SCTP, option, pointerof(value).as(Void*), sizeof(typeof(value)))
  end
end
