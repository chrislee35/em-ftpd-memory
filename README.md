# EM::FTPD::Memory

This is an in-memory fake filesystem for em-ftpd. 

## Installation

Add this line to your application's Gemfile:

    gem 'em-ftpd-memory'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install em-ftpd-memory

## Usage

	require 'eventmachine'
	require 'em/ftpd/memory'
	require 'em/ftpd'
	
    options = {
      "filesystem_name" => "boss",
      "authentication_realm" => "georgia",
      "pwalgo" => "otp",
      
    }
    auth = Authenticator.getAuthenticatorByRealm(options["authentication_realm"], options)
    auth << User.new("test", "test1\ntest2\ntest3\ntest4\ntest5")
    fs = FileSystem.getFileSystem(options["filesystem_name"])
    fs.create_dir("/pub", 'root')
    fs.create_file("/pub/helper.rb", "test/helper.rb", 'root')
    fs.set_permissions("/pub", 'rwxr.xr.x', "root")
    fs.create_dir("/uploads", 'root')
    fs.set_permissions("/uploads", "rwxrwxrwx", "root")
    
    fs.create_dir("/users", 'root')
    fs.set_permissions("/users", "rwxr.xr.x", "root")
    ["hiro", "miyako", "pilar"].each do |username|
      fs.create_dir("/users/#{username}", 'root')
      fs.set_permissions("/users/#{username}", "rwx......", "root")
      fs.set_owner("/users/#{username}", username, 'root')
      auth << User.new(username, username)
    end
    
    EM.run {
      EventMachine::start_server("0.0.0.0", 2021, EM::FTPD::Server, EM::FTPD::Memory::Driver, options)
    }

## Contributing

1. Fork it ( https://github.com/[my-github-username]/em-ftpd-memory/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
