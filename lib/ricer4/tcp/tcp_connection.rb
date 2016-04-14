module Ricer4::Plugins::Tcp
  class TcpConnection
    
    arm_events

    include Ricer4::Include::Threaded
    include Ricer4::Include::UserConnector

    IP_TRIES ||= {}
    IP_COOLDOWN ||= 10
    
    def initialize(connection, socket)
      @user = nil
      @server = connection.server
      @ip = socket.addr[3]
      @connection, @socket = connection, socket
      @mutex = Mutex.new
      IP_TRIES[@ip] = 0
      mainloop
    end
    
    def mainloop
      worker_threaded do
        begin
          bot.log.info("TCP Client #{@ip} connected.")
          write("201 CREATED CONNECTION WITH Ricer4.0a. WELCOME #{@ip}!")
          while line = @socket.gets
            raw_message(line.rtrim!)
          end
          write("410 CONNECTION CLOSED.")
          bot.log.info("TCP Client #{@ip} disconnected.")
        rescue StandardError => e
          bot.log.exception(e)
        rescue IOError
          bot.log.info("TCP Client #{@ip} disconnected.")
          @socket = nil
        ensure
          xlin_logout
        end
      end
    end
    
    def close
      xlin_logout    
    end
    
    def write(text)
      arm_signal(@server, "ricer/outgoing", text)
      @mutex.synchronize {
        @socket.puts(text) rescue xlin_logout
      }
      true
    end
    
    def netcat_usermask
      "#{@user.name}!#{@ip}@tcp-ricer4"
    end
    
    def raw_message(msg)

      message = Ricer4::Message.new
      message.raw = msg
      message.server = @server

      arm_publish("ricer/incoming", message.raw)
      arm_publish("ricer/receive", message)
      arm_publish("ricer/received", message)
      
      if @user
        message.prefix = @user.hostmask
        message.sender = @user
        message.type = "PRIVMSG"
        message.args = [@user.name, msg]
        arm_publish("ricer/messaged", message)
      else
        xlin, username, password = *msg.split(' ')
        if (xlin && (xlin.downcase == 'xlin')) && username && password
          @user = xlin_login(username, password, message)
        else
          write('401: XLIN username password MISSING - You are not logged in.')
        end
      end
    end
    
    def xlin_logout
      bot.log.debug("NCSocket#xlin_logout")
      if @user
        user_quit_server(@server, @user)
        @user.remove_instance_variable(:@ricer_netcat_socket)
        @user.logout!
        @user = nil
      end
      true
    end
    
    def xlin_auth_left
      IP_COOLDOWN - (Time.now.to_f - IP_TRIES[@ip])
    end
    
    def xlin_auth(user, password)
      if (left = xlin_auth_left) > 0
        write("402: BRUTEFORCE PROTECTION. WAIT #{left}s")
        return false
      elsif !user.password_matches?(password)
        write("403: AUTHENTICATION FAILURE.")
      elsif @user.instance_variable_defined?(:@ricer_netcat_socket)
        write("406: GHOST USER")
      else
        write('200: AUTHENTICATED!')
        return true
      end
      IP_TRIES[@ip] = Time.now.to_f
      false
    end
    
    def xlin_login(nickname, password, message)
      created = false
      user = get_user(@server, nickname)
      if user.nil?
        byebug
        user = create_user(@server, nickname)
        user.permissions = Ricer4::Permission::AUTHENTICATED.bit
        user.password = password
        write('200: REGISTERED!')
      else
        return nil unless xlin_auth(user, password)
      end
      
      @user = user
      
      # Connect user with this socket
      user.instance_variable_set(:@ricer_netcat_socket, self)

      # Setup his host mask
      user.hostmask = netcat_usermask
      user.login!
      user
    end
        
  end
end
