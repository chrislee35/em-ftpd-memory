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
    # set up the authentication
    auth = Authenticator.getAuthenticatorByRealm(options["authentication_realm"], options)
    # add a test user
    auth << User.new("test", "test1\ntest2\ntest3\ntest4\ntest5")
    # create the filesystem
    fs = FileSystem.getFileSystem(options["filesystem_name"])
    # add a pub folder
    fs.create_dir("/pub", 'root')
    # add a file to the pub folder as root
    fs.create_file("/pub/helper.rb", "test/helper.rb", 'root')
    # chmod 755 /pub
    fs.set_permissions("/pub", 'rwxr.xr.x', "root")
    # create /uploads as root
    fs.create_dir("/uploads", 'root')
    # chmod 777 /uploads
    fs.set_permissions("/uploads", "rwxrwxrwx", "root")
    # create /users as root
    fs.create_dir("/users", 'root')
    # chmod 755 /users
    fs.set_permissions("/users", "rwxr.xr.x", "root")
    # create a personal directory for hiro, miyako, and pilar, (and add their test user)
    ["hiro", "miyako", "pilar"].each do |username|
      fs.create_dir("/users/#{username}", 'root')
      # set the permissions so that no one else can access it
      fs.set_permissions("/users/#{username}", "rwx......", "root")
      # set the owner to the user
      fs.set_owner("/users/#{username}", username, 'root')
      auth << User.new(username, username)
    end
    
    EM.run {
      EventMachine::start_server("0.0.0.0", 2021, EM::FTPD::Server, EM::FTPD::Memory::Driver, options)
      EM::Timer.new(0.1) do
        EM.stop
      end
    }
  end
    
end