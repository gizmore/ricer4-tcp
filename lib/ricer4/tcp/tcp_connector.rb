###
### Raw TCP Connections (thx dloser)
###
module Ricer4::Connectors
  class Tcp < Ricer4::Connector
    
    def tcp
      bot.loader.get_plugin('Tcp/Tcp')
    end

    def protocol
      server.tls? ? 'ssl' : 'tcp'
    end

    def connect!
      begin
        @listener = server.tls? ? connect_ssl! : connect_tcp!
        @connected = true
        @thread = Ricer4::Thread.current
        server.set_online(true)
        mainloop
      rescue StandardError => e
        bot.log.exception(e)
      ensure
        server.set_online(false)
      end
    end
    
    def connect_tcp!
      bot.log.info("Tcp connector listen on port #{server.port}")
      TCPServer.new(server.port)
    end

    def connect_ssl!
      bot.log.info("Netcat connector listen with SSL on port #{server.port}")
      listener = TCPServer.new(server.port)
      sslContext = OpenSSL::SSL::SSLContext.new
      sslContext.cert = OpenSSL::X509::Certificate.new(File.open(tcp.public_key_path))
      sslContext.key = OpenSSL::PKey::RSA.new(File.open(tcp.private_key_path))
      sslServer = OpenSSL::SSL::SSLServer.new(listener, sslContext)
    end
    
    def disconnect!
      bot.log.info("Tcp connector disconnect!")
      @connected = false
      if @listener
        @listener.close
        @listener = nil
      end
    end
    
    def mainloop
      begin
        while @listener
          Ricer4::Plugins::Tcp::TcpConnection.new(self, @listener.accept)
        end
      rescue StandardError => e
        bot.log.error(e.message)
      ensure
        disconnect!
      end
    end
    
    ################
    ### Messages ###
    #################
    def send_reply(reply)
      send_to(reply.target, reply.text)
    end

    def send_to_all(line)
      server.users.online.each { |user| send_to(user, line) }
    end

    def send_to(user, text)
      begin
        if user.online
          user.instance_variable_get(:@ricer_netcat_socket).write(text)
        end
      rescue StandardError => e
        bot.log.exception(e)
      end
    end
    
    def send_quit(line)
      send_to_all("404: QUIT=#{line}")
      server.users.online.each do |user|
        user.instance_variable_get(:@ricer_netcat_socket).close
      end
      disconnect!
    end

  end
end
