require "../src/sctp"


# You can also use SCTPStreamServer and SCTPStreamSocket
# like TCPServer and TCPSocket.
# Only stream 0 will be used.

server = SCTPStreamServer.new "::", 9321

spawn do
  loop do
    socket = server.accept
    process(socket)
  end
end

def process(socket)
  socket.flush_on_newline = true
  loop do
    case socket.gets
    when "local\n"
      socket.puts Time.now.to_s("%Y-%m-%d %H:%M:%S")
    when "utc\n"
      socket.puts Time.utc_now.to_s("%Y-%m-%d %H:%M:%S")
    when "close\n"
      socket.close
    else
      socket.puts("¯\\(ツ)/¯")
    end
  end
end

client = SCTPStreamSocket.new("::1",9321)
client.flush_on_newline = true

client.puts "local"
puts "local time is #{client.gets}"

client.puts "utc"
puts "utc time is #{client.gets}"

client.puts "close"
client.close
