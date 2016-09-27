struct SCTPMessage
  getter stream_no : UInt16
  getter data : Slice(UInt8)
  getter address : Socket::IPAddress
  getter socket : SCTPBaseSocket

  def initialize(@data : Slice(UInt8), @stream_no : UInt16, @address : Socket::IPAddress, @socket : SCTPBaseSocket)
  end

  def respond(response : Slice(UInt8))
    socket.send(response, stream_no, address)
  end

  def respond(response)
    socket.send(response, stream_no, address)
  end

  def echo
    send
  end

  def send
    socket.send(data, stream_no, address)
  end

  def data_as_string
    String.new data
  end

  def gets
    data_as_string
  end

  def puts(string : String)
    respond(string)
  end
end
