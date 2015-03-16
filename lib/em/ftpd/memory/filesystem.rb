module EM::FTPD::Memory
  class InvalidPermissionsError < StandardError; end
  
  class FileSystem
    @@filesystems = Hash.new
    def self.getFileSystem(name)
      if @@filesystems[name].nil?
        @@filesystems[name] = FileSystem.new
      end
      #puts "returning FileSystem named #{name}"
      return @@filesystems[name]
    end
    
    def self.destroyFileSystem(name, force = false)
      unless @@filesystems[name].nil?
        if force
          @@filesystems[name].destroy
          @@filesystems.delete(name)
        else
          if @@filesystems[name].list_files("/").empty?
            @@filesystems.delete(name)
          end
        end
      end
    end
    
    def initialize()
      @root_entry = EM::FTPD::DirectoryItem.new(:name => 'root', :directory => true, :size => 0, :permissions => 'rwxrwxrwx', :owner => 'root', :group => 'root')
      @root = {
        '/' => Array.new
      }
      @contents = Hash.new
    end

    def exist?(path)
      is_dir(path) || is_file(path)
    end
    
    def change_dir(path, user = nil)
      is_dir(path) && use_allowed?(path, :list, user)
    end
    
    def list_files(path, user = nil)
      return [] unless use_allowed?(path, :list, user)
      @root[path] || [] # should this return false?
    end
    
    def file_size(path, user = nil)
      return false unless use_allowed?(path, :size, user)
      f = get_file(path)
      return false unless f
      f.size
    end
    
    def modified_time(path, user = nil)
      return nil unless use_allowed?(path, :time, user)
      f = get_file(path)
      return nil unless f
      f.time
    end
    
    def file_contents(path, user = nil)
      return false unless use_allowed?(path, :read, user)
      # nil || false => false
      @contents[path] || false
    end
    
    def create_file(path, data, user = "nobody")
      return false unless use_allowed?(path, :create, user)
      dirname = File.dirname(path)
      basename = File.basename(path)
      if is_dir(dirname)
        contents = File.open(data,'r').read
        f = get_file(path)
        if f
          f.size = contents.length
        else
          @root[dirname] << EM::FTPD::DirectoryItem.new(:name => basename, :directory => false, :size => contents.length)
        end
        @contents[path] = contents
        return true
      else
        return false
      end
    end
    
    def delete_file(path, user = nil)
      if is_file(path)
        return false unless use_allowed?(path, :delete, user)
        dirname = File.dirname(path)
        basename = File.basename(path)
        @root[dirname].reject! {|file| file.directory == false && file.name == basename}
        @contents.delete(path)
        return true
      end
      false
    end
    
    def delete_dir(path, user = nil)
      if is_dir(path) && @root[path].empty?
        return false unless use_allowed?(path, :delete, user)
        @root.delete(path)
        dirname = File.dirname(path)
        basename = File.basename(path)
        @root[dirname].reject! {|file| file.directory == true && file.name == basename}
        return true
      end
      false
    end
    
    def create_dir(path, user = "nobody")
      if not exist?(path)
        return false unless use_allowed?(path, :create, user)
        dirname = File.dirname(path)
        basename = File.basename(path)
        if is_dir(dirname)
          @root[path] = Array.new
          @root[dirname] << EM::FTPD::DirectoryItem.new(:name => basename, :directory => true, :size => 0)
          return true
        end
      end
      return false
    end
    
    def rename(from, to, user = nil)
      return false if exist?(to)
      return false unless exist?(from)
      return false unless use_allowed?(from, :delete, user)
      return false unless use_allowed?(to, :create, user)
      
      from_dirname = File.dirname(from)
      from_basename = File.basename(from)
      to_dirname = File.dirname(to)
      to_basename = File.basename(to)
      
      if from_dirname == to_dirname
        @root[from_dirname].find {|file| file.name == from_basename}.name = to_basename
      else
        entry = @root[from_dirname].find {|file| file.name == from_basename}
        @root[from_dirname] -= [entry]
        entry.name = to_basename
        @root[to_dirname] << entry
      end
      
      if is_dir(from)
        @root[to] = @root[from]
        @root.delete(from)
      else
        # @contents[to] points to the same reference/pointer as @contents[from]
        # i.e., this is not a copy, they point to the same object
        @contents[to] = @contents[from]
        @contents.delete(from)
      end
      return true
    end
    
    def destroy
      @root.each_key do |d|
        @root.delete(d)
      end
      @contents.each_key do |f|
        @contents.delete(f)
      end
      GC.start
    end
    
    def set_permissions(path, permissions, user = nil)
      return false unless exist?(path)
      raise InvalidPermissionsError.new if permissions.nil?
      raise InvalidPermissionsError.new(permissions.to_s) unless permissions.class == String
      raise InvalidPermissionsError.new(permissions) unless permissions =~ /^[r\.][w\.][x\.][r\.][w\.][x\.][r\.][w\.][x\.]$/
      if use_allowed?(path, :chmod, user)
        entry = get_entry(path)
        entry.permissions = permissions
        return true
      end
      false
    end
    
    def set_owner(path, owner, user = nil)
      return false unless exist?(path) and owner and owner.class == String
      entry = get_entry(path)
      return false unless user and user == "root"
      return false unless entry
      entry.owner = owner
      true
    end

    #private 
    
    def get_entry(path)
      return @root_entry if path == '/'
      dirname = File.dirname(path)
      basename = File.basename(path)
      if is_dir(dirname)
        return @root[dirname].find {|entry| entry.name == basename}
      end
      nil
    end
    
    def get_file(path)
      dirname = File.dirname(path)
      basename = File.basename(path)
      if is_dir(dirname)
        return @root[dirname].find {|file| file.directory == false && file.name == basename}
      end
      nil
    end
    
    def is_file(path)
      @contents[path] || false
    end
    
    def is_dir(path)
      @root[path] != nil
    end
    
    def use_allowed?(path, use, username)
      return true if username == 'root'
      
      dirname = File.dirname(path)
      basename = File.basename(path)
      # to do anything, you must be able to rx into the directory containing the entry
      cwd = '/'
      dirname.split(/\//).each do |dir|
        next if dir == '/'
        cwd << dir
        return false unless allowed?(cwd, "rx", username)
        cwd << '/'
      end
      
      case use
      when :read
        return allowed?(path, 'r', username)
      when :write
        return allowed?(path, 'w', username)
      when :list
        return allowed?(path, 'rx', username)
      when :size
        return true # since we've already checked everything
      when :time
        return true # since we've already checked everything
      when :chmod
        entry = get_entry(path)
        return entry.owner == username
      when :delete
        return allowed?(dirname, "rwx", username)
      when :create
        return allowed?(dirname, "rwx", username)
      else
        return false
      end
    end
    
    def allowed?(path, required_permissions, username)
      entry = get_entry(path)
      permissions = entry.permissions || 'rwxrwxrwx'
      return false unless entry
      if username.nil?
        perms = permissions[6,3]
      elsif entry.owner == username
        perms = permissions[0,3]
      else
        perms = permissions[6,3]
      end

      return true if perms == "rwx"
      required_permissions.each_char do |c|
        if perms.index(c).nil?
          return false
        end
      end
      return true
    end

  end
end