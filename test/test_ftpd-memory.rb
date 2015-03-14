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

class TestFTPDMemory < Minitest::Test
  def test_example
    options = {
      "filesystem_name" => "boss",
      "authentication_realm" => "georgia",
      "pwalgo" => "otp",
      
    }
    auth = EM::FTPD::Memory::Authenticator.getAuthenticatorByRealm(options["authentication_realm"], options)
    auth << EM::FTPD::Memory::User.new("test", "test1\ntest2\ntest3\ntest4\ntest5")
    fs = EM::FTPD::Memory::FileSystem.getFileSystemByName(options["filesystem_name"])
    fs.create_dir("/pub")
    fs.create_file("/pub/helper.rb", "test/helper.rb")
    
    EM.run {
      EventMachine::start_server("0.0.0.0", 2021, EM::FTPD::Server, EM::FTPD::Memory::Driver, options)
      EM::Timer.new(0.1) do
        EM.stop
      end
    }
  end
  
  def test_plain_login
  end
  
  def test_time_based_login
  end
  
  def test_otp_login
  end
  
  def test_file_creation
  end
  
  def test_file_deletion
  end
  
  def test_create_directory
  end
  
  def test_delete_directory
  end
  
  def test_file_rename
  end
  
  def test_file_move_between_directories
  end
  
  def test_chmod_file
  end
  
  def test_chmod_directory
  end
  
end