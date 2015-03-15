unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'eventmachine'
require 'em-ftpd'
require 'digest/md5'
include EM::FTPD::Memory

class TestFTPDMemory < Minitest::Test
  def test_example
    options = {
      "filesystem_name" => "boss",
      "authentication_realm" => "georgia",
      "pwalgo" => "otp",
      
    }
    auth = Authenticator.getAuthenticatorByRealm(options["authentication_realm"], options)
    auth << User.new("test", "test1\ntest2\ntest3\ntest4\ntest5")
    fs = FileSystem.getFileSystem(options["filesystem_name"])
    fs.create_dir("/pub")
    fs.create_file("/pub/helper.rb", "test/helper.rb")
    
    EM.run {
      EventMachine::start_server("0.0.0.0", 2021, EM::FTPD::Server, EM::FTPD::Memory::Driver, options)
      EM::Timer.new(0.1) do
        EM.stop
      end
    }
  end
    
end