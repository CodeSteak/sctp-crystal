require "../src/sctp"

server = SCTPServer.new "::0", 9000
spawn do
  loop do
    data, stream, address = server.receive
    puts "in : "
    puts String.new data
  end
end

client = SCTPSocket.new
addr   = client.address("::1",9000) #defaults to IPv6

10.times do |i|
  client.send("Uhhh DATTAAH! on stream_no #{i}", i, addr)
  sleep 0.5
end
