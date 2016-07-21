require "../src/sctp"

#Time Server
def run_server
  server = SCTPServer.new "::0", 9000

  spawn do
    loop do
      data, stream, address = server.receive
      req = String.new data

      case req
      when "local"
        server.send(Time.now.to_s("%Y-%m-%d %H:%M:%S"),stream,address)
      when "utc"
        server.send(Time.utc_now.to_s("%Y-%m-%d %H:%M:%S"),stream,address)
      else
        server.send("¯\\(ツ)/¯",stream,address)
      end
    end
  end
end

def run_client

  socket = SCTPSocket.new
  server_addr = socket.address("::1", 9000)

  channel_local_time = socket[1, server_addr]

  channel_utc_time = socket[2, server_addr]


  # Messages are only delivered to SCTPChannels
  # when receive is called, so messages from
  # other streams or hosts can be caught.
  #
  spawn do
    data, stream, address = socket.receive
    puts "err : ", String.new(data), {stream, address}
  end

  channel_local_time.send("local")
  channel_utc_time.send("utc")

  puts "utc time :", channel_utc_time.receive_string
  channel_utc_time.close

  puts "local time :", channel_local_time.receive_string
  channel_local_time.close
end

run_server
run_client
