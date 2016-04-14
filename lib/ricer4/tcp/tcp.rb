module Ricer4::Plugins::Tcp
  class Tcp < Ricer4::Plugin
    
    has_files

    arm_install do |m|
      require "openssl"
      bot.log.info{"TCP plugin generates RSA keys."}
      key = OpenSSL::PKey::RSA.new 4096
      open plugin_file_path('private_key.pem'), 'w' do |io| io.write key.to_pem end
      open plugin_file_path('public_key.pem'), 'w' do |io| io.write key.public_key.to_pem end
    end
    
    def plugin_init
      
    end
    
  end
end