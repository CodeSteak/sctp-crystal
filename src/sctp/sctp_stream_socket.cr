# Comming soon
class SCTPStreamSocket < IPSocket
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_SCTP, timeout: dns_timeout) do |addrinfo|
      super(create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol))
      if err = nonblocking_connect host, port, addrinfo, timeout: connect_timeout
        close
        next false if addrinfo.ai_next
        raise err
      end
      enable_sctp_data_io_event
      true
    end
  end

  def initialize(fd : Int32)
    super fd
    enable_sctp_data_io_event
  end

  private def enable_sctp_data_io_event
    event = LibC::SctpEventSubscribe.new
    event.sctp_data_io_event = 1_u8
    set_socketopt(LibC::SCTP_EVENTS, event)
  end

  def set_socketopt(option : Int32, value)
    LibC.setsockopt(@fd, LibC::IPPROTO_SCTP, option, pointerof(value).as(Void*), sizeof(typeof(value)))
  end

  def self.open(host, port)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  class SCTPStreamChannel
    include IO::Buffered
    getter stream_no : UInt16
    getter parent : SCTPStreamSocket
    @in_channel : Channel::Buffered(Slice(UInt8))

    def initialize(@parent : SCTPStreamSocket, sctp_stream_no : UInt16 | Int32)
      @stream_no = sctp_stream_no.to_u16
      in_channel = Channel::Buffered(Slice(UInt8)).new
      @parent.register_stream_channel(in_channel, sctp_stream_no)
      @in_channel = in_channel
    end

    # Reads at most *slice.size* bytes from the wrapped IO into *slice*. Returns the number of bytes read.
    def unbuffered_read(slice : Slice(UInt8))
      rev = @in_channel.receive
      raise IndexError.new("Strage behaviour of IO::Buffered") if (rev.size > slice.size)
      slice.copy_from(rev.pointer(rev.size), rev.size)
      rev.size
    end

    # Writes at most *slice.size* bytes from *slice* into the wrapped IO. Returns the number of bytes written.
    def unbuffered_write(slice : Slice(UInt8))
      @parent.send(slice, @stream_no)
    end

    # Flushes the wrapped IO.
    def unbuffered_flush
      @parent.flush
    end

    # Closes the wrapped IO.
    def unbuffered_close
      @parent.flush
      @parent.unregister_stream_channel(@stream_no)
    end

    # Rewinds the wrapped IO.
    def unbuffered_rewind
      # TODO: Handle
    end

    def closed?
      @parent.closed?
    end
  end

  @stream_channel = Hash(UInt16, Channel::Buffered(Slice(UInt8))).new

  def register_stream_channel(channel : Channel::Buffered(Slice(UInt8)), stream_no : UInt16)
    @stream_channel[stream_no] = channel
  end

  def unregister_stream_channel(stream_no : UInt16)
    @stream_channel.delete(stream_no)
  end

  def [](stream_no : UInt16 | Int32)
    raise Error.new "Error opening SCTPStreamChannel Object: it already exits" if @stream_channel[stream_no.to_u16]?
    SCTPStreamChannel.new(self, stream_no.to_u16)
  end

  def process
    while !closed?
      yield receive
    end
  rescue ex
    raise ex unless closed?
  end

  def receive : SCTPStreamChannel
    loop do
      slice = Slice(UInt8).new 8196
      len, stream_no = receive(slice)

      if ch = @stream_channel[stream_no]?
        ch.send(slice[0, len])
      else
        nch = SCTPStreamChannel.new self, stream_no
        nch.@in_channel.send(slice[0, len])
        return nch
      end
    end
  end

  def receive(slice : Slice(UInt8)) : {Int32, UInt16}
    loop do
      sockaddr = uninitialized LibC::SockaddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      sndrcvinfo = uninitialized LibC::SctpSndrcvinfo
      flags = 0

      #  fun sctp_recvmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, from : Sockaddr*, fromlen : SocklenT*, sinfo : SctpSndrcvinfo*, msg_flags : LibC::Int*) : LibC::Int
      bytes_read = LibC.sctp_recvmsg(@fd, (slice.to_unsafe.as(Void*)), slice.size, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen), pointerof(sndrcvinfo), pointerof(flags))

      @closed = true if bytes_read == 0

      if bytes_read != -1
        return {
          bytes_read.to_i32,
          sndrcvinfo.sinfo_stream,
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

  def send(slice : Slice(UInt8), stream_no : UInt16) : Int32
    loop do
      flags = 0
      #   fun sctp_sendmsg(s : LibC::Int, msg : Void*, len : LibC::SizeT, to : Sockaddr*, tolen : SocklenT, ppid : Uint32T, flags : Uint32T, stream_no : Uint16T, timetolive : Uint32T, context : Uint32T) : LibC::Int
      bytes_sent = LibC.sctp_sendmsg(@fd, slice.to_unsafe.as(Void*), slice.size, Pointer(LibC::Sockaddr).null, 0, 0, flags, stream_no, 0, 0)

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
end
