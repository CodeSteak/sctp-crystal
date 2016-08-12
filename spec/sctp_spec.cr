require "./spec_helper"

describe "sctp_socket" do
  it "open server, connect and echo" do
    begin
      msg = "Hello SCTP"

      server = SCTPServer.new "::0", 9002
      server.read_timeout = 1
      server.write_timeout = 1

      server.on_message do |msg|
        puts "whut?!"
        puts msg.gets
        puts msg.address
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
      server.on_message do |msg|
        puts "?????!"
      end
    end
  end

  it "use channels" do

    server = SCTPServer.new "::0", 9010
    server.read_timeout = 1
    server.write_timeout = 1

    a = 0
    server.on_message do |msg|
      puts "lol"
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

    client.read_timeout = 1
    client.write_timeout = 1

    addr = client.address("::1", 9010) # defaults to IPv6

    client.send("-", 9, addr)
    client.send("-", 3, addr)

    sleep 1

    b.should eq(1)
    a.should eq(1)


    client.close
    server.close
  end
end
