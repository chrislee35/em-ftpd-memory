module EM::FTPD::Memory
  class Driver
    def initialize(options = {})
      filesystem_name = options["filesystem_name"] || "default"
      realm = options["authentication_realm"] || "default"
      @fs = FileSystem.getFileSystemByName(filesystem_name)
      @authenticator = Authenticator.getAuthenticatorByRealm(realm, options)
    end
    
    def change_dir(path, &block)
      yield @fs.is_dir(path)
    end

    def dir_contents(path, &block)
      yield @fs.list_files(path)
    end

    def authenticate(user, pass, &block)
      begin
        @authenticator.authenticate(user, pass)
        yield true
      rescue Exception => e
        #puts e.backtrace
        yield false
      end
    end

    def bytes(path, &block)
      yield @fs.file_size(path)
    end

    def get_file(path, &block)
      yield @fs.file_contents(path)
    end

    def put_file(path, data, &block)
      yield @fs.create_file(path, data)
    end

    def delete_file(path, &block)
      yield @fs.remove_file(path)
    end

    def delete_dir(path, &block)
      yield @fs.delete_dir(path)
    end

    def rename(from, to, &block)
      yield @fs.rename(from, to)
    end

    def make_dir(path, &block)
      yield @fs.create_dir(path)
    end    
  end
end