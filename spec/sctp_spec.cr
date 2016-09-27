require "./spec_helper"

describe "SCTPSocket and SCTPServer" do
  it "open server, connect and echo" do
    msg = "Hello SCTP"

    server = SCTPServer.new "::0", 9002

    server.read_timeout = 1
    server.write_timeout = 1

    server.on_message do |msg|
      msg.echo
    end

    client = SCTPSocket.new
    client.read_timeout = 1
    client.write_timeout = 1

    addr = client.address("::1", 9002) # defaults to IPv6
    client.send(msg, 6, addr)

    in_msg = client.receive

    in_msg.gets.should eq(msg)
    in_msg.stream_no.should eq(6)

    client.close
    server.close
  end

  it "use channels" do
    server = SCTPServer.new "::0", 9010
    server.read_timeout = 1
    server.write_timeout = 1

    a = 0
    server.on_message do |msg|
      a += 1
    end

    b = 0
    server.on_message(3_u16) do |msg|
      msg.respond "No. 3"
      b += 1
    end

    client = SCTPSocket.new
    client.read_timeout = 1
    client.write_timeout = 1

    addr = client.address("::1", 9010) # defaults to IPv6

    client.send("-", 9, addr)
    client.send("-", 3, addr)

    sleep 0.1

    a.should eq(1)
    b.should eq(1)

    client.close
    server.close
  end
end

describe "SCTPStreamSocket and SCTPStreamServer" do
  it "open server, connect and echo" do
    server = SCTPStreamServer.new "::0", 9102
    server.read_timeout = 1
    server.write_timeout = 1

    client = SCTPStreamSocket.new "::1", 9102
    client.read_timeout = 1
    client.write_timeout = 1

    spawn do
      server_client = server.accept?

      if server_client
        tmp_client = server_client
        tmp_client.read_timeout = 1
        tmp_client.write_timeout = 1

        tmp_client.on_message do |msg|
          msg.respond "Any"
          if c = tmp_client
            c.close
          end
          server.close
        end

        tmp_client.on_message(3_u16) do |msg|
          msg.respond "No. 3"
        end
      end
    end

    client.send "AAA", 3
    in_msg_a = client.receive

    client.puts "BBB"
    in_msg_b = client.receive

    client.close

    in_msg_a.gets.should eq("No. 3")
    in_msg_a.stream_no.should eq(3)

    in_msg_b.gets.should eq("Any")
  end

  it "performs IPv4 and TCP-like use" do
    server = SCTPStreamServer.new "0.0.0.0", 9302
    server.read_timeout = 1
    server.write_timeout = 1

    client = SCTPStreamSocket.new "127.0.0.1", 9302
    client.read_timeout = 1
    client.write_timeout = 1

    spawn do
      c = server.accept
      c.read_timeout = 1
      c.write_timeout = 1
      input = c.gets
      c.puts input
      c.flush
      c.close
    end

    client.puts "AAA"
    client.flush
    client.gets.should eq("AAA\n")

    client.close
    server.close
  end
end
