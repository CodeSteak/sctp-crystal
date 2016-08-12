require "../src/sctp"

# ## OUTDATED TODO: Update

# Time Server
def run_server
  server = SCTPServer.new "::0", 9000
  server.autoclose = 30 # seconds
  spawn do
    loop do
      request = server.receive

      case request.gets
      when "local"
        request.respond Time.now.to_s("%Y-%m-%d %H:%M:%S")
      when "utc"
        request.respond Time.utc_now.to_s("%Y-%m-%d %H:%M:%S")
      else
        request.respond("¯\\(ツ)/¯")
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
  # when `receive` is called, so messages from
  # other streams or hosts can be caught.
  # This can also be done with `process`.
  spawn do
    socket.process do |msg|
      puts "err : ", msg
    end
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
