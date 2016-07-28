require "../src/sctp"

#Bad Example, I know. But good for testing.

server = SCTPStreamServer.new(9666)

spawn do
  loop do
    socket = server.accept
    puts "Client connected"
    socket.process do |new_stream|
      puts "new stream #{new_stream.stream_no}"
      spawn do
        rn = new_stream.read_byte
        n = if rn
          rn.to_i32 * 1000
        else
          0
        end
        n.times do
          new_stream.write_byte new_stream.stream_no.to_u8
        end
        new_stream.close
      end
    end
  end
end

client = SCTPStreamSocket.new("::1",9666)

ch6 = client[6]
ch6.write_byte 30_u8
ch6.flush
spawn do
  30000.times do
    ch6.read_byte
  end
  puts "okey 6"
  ch6.close
  sleep 1
  client.close
end

ch5 = client[5]
ch5.write_byte 100_u8
ch5.flush
spawn do
  100000.times do
    ch5.read_byte
  end
  puts "okey 5"
  ch5.close
  sleep 1
  client.close
end
client.process do |new_stream|
  puts "cant handle", new_stream
end
