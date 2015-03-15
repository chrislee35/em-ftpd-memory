module EM::FTPD::Memory
  class Driver
    def initialize(options = {})
      filesystem_name = options["filesystem_name"] || "default"
      realm = options["authentication_realm"] || "default"
      @fs = FileSystem.getFileSystem(filesystem_name)
      @authenticator = Authenticator.getAuthenticatorByRealm(realm, options)
      @authenticated_user = nil
      @server = Kernel.caller[0]
      begin
        $stderr.puts @server
      rescue => e
        $stderr.puts e
        $stderr.puts e.backtrace
      end
    end
    
    def change_dir(path, &block)
      yield @fs.change_dir(path, @authenticated_user)
    end

    def dir_contents(path, &block)
      yield @fs.list_files(path, @authenticated_user)
    end

    def authenticate(user, pass, &block)
      begin
        @authenticator.authenticate(user, pass)
        @authenticated_user = user
        yield true
      rescue Exception => e
        #puts e.backtrace
        yield false
      end
    end

    def bytes(path, &block)
      yield @fs.file_size(path, @authenticated_user)
    end

    def get_file(path, &block)
      yield @fs.file_contents(path, @authenticated_user)
    end

    def put_file(path, data, &block)
      yield @fs.create_file(path, data, @authenticated_user)
    end

    def delete_file(path, &block)
      yield @fs.delete_file(path, @authenticated_user)
    end

    def delete_dir(path, &block)
      yield @fs.delete_dir(path, @authenticated_user)
    end

    def rename(from, to, &block)
      yield @fs.rename(from, to, @authenticated_user)
    end

    def make_dir(path, &block)
      yield @fs.create_dir(path, @authenticated_user)
    end
    
  end
end