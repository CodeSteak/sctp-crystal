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
  client.send(i, addr, "Uhhh DATTAAH! on stream_no #{i}")
  sleep 0.5
end

addr2   = client.addressv4("127.0.0.1",9000)

10.times do |i|
  client.send(i+58, addr2, "Uhhh MORE DATTAAH! on stream_no #{i}")
  sleep 0.25
end
