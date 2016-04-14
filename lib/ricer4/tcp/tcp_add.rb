module Ricer4::Plugins::Tcp
  class Add < Ricer4::Plugin
    
    trigger_is "tcp.add"
    
    has_usage '<port>'
    has_usage '<port> <boolean|named:"ssl">'
    def execute(port, ssl=false)
      server = Ricer4::Server.find_or_create_by({
        conector: 'tcp'
      })
      updated = server.port != nil
      server.hostname = 'localhost'
      server.port = port
      server.tls = ssl ? 1 : 0
      server.save!
      key = updated ? :msg_updated : :msg_created
      rply key, port: port
    end
    
  end
end