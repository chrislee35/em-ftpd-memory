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
      "authentication_realm" => "georgia"
    }
    # set up the authentication
    auth = Authenticator.getAuthenticatorByRealm(options["authentication_realm"])
    # add a test user
    auth << User.new(:name => "test", :algo => "otp", :credential => "test1\ntest2\ntest3\ntest4\ntest5")
    # add an anonymous user, note: algo defaults to none if there are no credentials are specified
    auth << User.new(:name => "anonymous")
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
      # create a home directory
      fs.create_dir("/users/#{username}", 'root')
      # set the permissions so that no one else can access it
      fs.set_permissions("/users/#{username}", "rwx......", "root")
      # set the owner to the user
      fs.set_owner("/users/#{username}", username, 'root')
      # add the user to the authentication realm
      auth << User.new(:name => username, :algo => "plain", :credential => username, :groups => ["testing"])
    end
    
    # since hiro, miyako, and pilar are all in the "testing" group, I can
    # create a shared folder for them, but the "test" user won't be able to access
    fs.create_dir("/shared", 'root')
    fs.set_permissions("/shared", 'rwxr.xr.x', 'root')
    fs.create_dir("/shared/testing", 'root')
    fs.set_group("/shared/testing", 'testing', 'root')
    fs.set_permissions("/shared/testing", 'rwxrwx...', 'root')
     
    EM.run {
      EventMachine::start_server("0.0.0.0", 2021, EM::FTPD::Server, EM::FTPD::Memory::Driver, options)
    }

## Contributing

1. Fork it ( https://github.com/[my-github-username]/em-ftpd-memory/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
