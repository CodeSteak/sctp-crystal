require "../../src/sctp"
describe "sctp_socket" do

  it "open server, connect and echo" do
    msg = "Hello SCTP"

    server = SCTPServer.new "::0", 9000

    spawn do
      in_msg = server.receive
      in_msg.echo
      server.close
    end

    client = SCTPSocket.new
    addr   = client.address("::1",9000) #defaults to IPv6
    client.send(msg, 6, addr)

    in_msg = client.receive

    in_msg.gets.should eq(msg)
    in_msg.stream_no.should eq(6)

    client.close
  end

  it "use channels" do

      client = SCTPSocket.new
      server_addr = client.address("::1", 9001)

      channel_one = client[1, server_addr]
      channel_three = client[3, server_addr]

      server = SCTPServer.new "::0", 9001
      spawn do
        msg = server.receive
        address = msg.address
        server.send("one", 1, address)
        server.send("three", 3, address)
        msg = server.receive
        server.send("three", 3, address)
        server.close
      end

      testch = Channel(String).new

      client.send("-", 0, server_addr)
      spawn do
        client.process do |msg|
          testch.send(String.new msg.data)
        end
      end
      channel_three.receive_string.should eq("three")
      channel_one.receive_string.should eq("one")

      channel_three.close
      client.send("-", 0, server_addr)
      testch.receive.should eq("three")
      client.close
  end

end
