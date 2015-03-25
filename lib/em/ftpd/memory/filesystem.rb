module EM::FTPD::Memory
  class InvalidPermissionsError < StandardError; end
  
  class MemoryDirectoryItem
    ATTRS = [:name, :owner, :group, :size, :time, :permissions, :directory, :contents]
    attr_accessor(*ATTRS)

    def initialize(options)
      options.each do |attr, value|
        self.send("#{attr}=", value)
      end
      @size ||= 0
      @time ||= Time.now
      @owner ||= "nobody"
      @group ||= "nogroup"
      raise ArgumentError.new("MemoryDirectoryItem requires a :name") unless @name
    end
  end
  
  class FileSystem
    @@filesystems = Hash.new
    def self.getFileSystem(name)
      if @@filesystems[name].nil?
        @@filesystems[name] = FileSystem.new
      end
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


    def initialize
      @root = MemoryDirectoryItem.new(
        :name => '/', 
        :owner => 'root', 
        :group => 'root', 
        :directory => true, 
        :permissions => "rwxr.xr.x", 
        :contents => Hash.new
      )
    end

    def exist?(path)
      item = get_item(path)
      if item
        return true
      else
        return false
      end
    end
    
    def is_dir?(path)
      item = get_item(path)
      return false unless item and item.directory
      true
    end
    
    def is_file?(path)
      item = get_item(path)
      return false unless item and not item.directory
      true
    end
    
    def change_dir(path, user = nil, groups = [])
      item = get_item(path)
      item.directory && use_allowed?(path, :list, user, groups)
    end
    
    def list_files(path, user = nil, groups = [])
      return [] unless use_allowed?(path, :list, user, groups)
      item = get_item(path)
      if item.directory
        return item.contents.values
      end
      return []
    end
    
    def file_size(path, user = nil, groups = [])
      return false unless use_allowed?(path, :size, user, groups)
      f = get_item(path)
      return false unless f
      f.size
    end
    
    def modified_time(path, user = nil, groups = [])
      return nil unless use_allowed?(path, :time, user, groups)
      f = get_item(path)
      return nil unless f
      f.time
    end
    
    def file_contents(path, user = nil, groups = [])
      return false unless use_allowed?(path, :read, user, groups)
      item = get_item(path)
      item.contents || false
    end
    
    def create_file(path, data, user = "nobody", groups = [])
      return false unless use_allowed?(path, :create, user, groups)
      dirname = File.dirname(path)
      basename = File.basename(path)
      dir = get_item(dirname)
      if dir and dir.directory
        item = get_item(path)
        contents = File.open(data,'r').read
        permissions = "rwxrwxrwx" # FIXME
        if item # overwrite
          item.contents = contents
          item.size = contents.length
        else # create new
          dir.contents[basename] = MemoryDirectoryItem.new(
            :name => basename, 
            :owner => user,
            :group => groups.first || "nogroup",
            :size => contents.length,
            :contents => contents, 
            :permissions => permissions
          )
        end
        return true
      else
        return false
      end
    end
    
    def delete_file(path, user = nil, groups = [])
      return false unless use_allowed?(path, :delete, user, groups)
      dirname = File.dirname(path)
      basename = File.basename(path)
      dir = get_item(dirname)
      if dir and dir.directory and dir.contents[basename]
        dir.contents.delete(basename)
        return true
      end
      false
    end
    
    def delete_dir(path, user = nil, groups = [])
      dir = get_item(path)
      if dir and dir.directory and dir.contents.empty?
        return false unless use_allowed?(path, :delete, user, groups)
        dirname = File.dirname(path)
        basename = File.basename(path)
        parent = get_item(dirname)
        parent.contents.delete(basename)
        return true
      end
      false
    end
    
    def create_dir(path, user = "nobody", groups = [])
      dir = get_item(path)
      if dir.nil?
        return false unless use_allowed?(path, :create, user, groups)
        dirname = File.dirname(path)
        basename = File.basename(path)
        parent = get_item(dirname)
        if parent and parent.directory
          parent.contents[basename] = MemoryDirectoryItem.new(
            :name => basename, 
            :directory => true, 
            :owner => user, 
            :group => groups.first || "nogroup",
            :contents => Hash.new
          )
          return true
        end
      end
      return false
    end
    
    def rename(from, to, user = nil, groups = [])
      titem = get_item(to)
      return false if titem
      fitem = get_item(from)
      return false unless fitem
      return false unless use_allowed?(from, :delete, user, groups)
      return false unless use_allowed?(to, :create, user, groups)
      
      from_dirname = File.dirname(from)
      from_basename = File.basename(from)
      to_dirname = File.dirname(to)
      to_basename = File.basename(to)
      
      dir1 = get_item(from_dirname)
      dir2 = get_item(to_dirname)
      fitem.name = to_basename
      dir2.contents[to_basename] = fitem
      dir1.contents.delete(from_basename)
      
      return true
    end
    
    def destroy
      @root = MemoryDirectoryItem.new(
        :name => '/', 
        :owner => 'root', 
        :group => 'root', 
        :directory => true, 
        :permissions => "rwxr.xr.x", 
        :contents => Hash.new
      )
      GC.start
    end
    
    def set_permissions(path, permissions, user = nil, groups = [])
      item = get_item(path)
      return false unless item
      raise InvalidPermissionsError.new if permissions.nil?
      raise InvalidPermissionsError.new(permissions.to_s) unless permissions.class == String
      raise InvalidPermissionsError.new(permissions) unless permissions =~ /^[r\.][w\.][x\.][r\.][w\.][x\.][r\.][w\.][x\.]$/
      if use_allowed?(path, :chmod, user, groups)
        item.permissions = permissions
        return true
      end
      false
    end
    
    def set_owner(path, owner, user = nil, groups = [])
      item = get_item(path)
      return false unless item and owner and owner.class == String
      return false unless user and user == "root"
      item.owner = owner
      true
    end
    
    def set_group(path, group, user = nil, groups = [])
      item = get_item(path)
      return false unless item and group and group.class == String
      return false unless (user and user == "root") or groups.index(group)
      item.group = group
      true
    end

    #private
    
    def get_item(path)
      cur = @root
      path.split(/\//).each do |part|
        next if part == ""
        raise ArgumentError.new("Use of . and .. are forbidden") if part == "." or part == ".."
        cur = cur.contents[part]
        return nil if cur.nil?
      end
      cur
    end
    
    def use_allowed?(path, use, username, groups = [])
      return true if username == 'root'
      
      dirname = File.dirname(path)
      basename = File.basename(path)
      # to do anything, you must be able to rx into the directory containing the entry
      cwd = '/'
      dirname.split(/\//).each do |dir|
        next if dir == '/'
        cwd << dir
        return false unless allowed?(cwd, "rx", username, groups)
        cwd << '/'
      end
      
      case use
      when :read
        return allowed?(path, 'r', username, groups)
      when :write
        return allowed?(path, 'w', username, groups)
      when :list
        return allowed?(path, 'rx', username, groups)
      when :size
        return true # since we've already checked everything
      when :time
        return true # since we've already checked everything
      when :chmod
        item = get_item(path)
        return item.owner == username
      when :delete
        return allowed?(dirname, "rwx", username, groups)
      when :create
        return allowed?(dirname, "rwx", username, groups)
      else
        return false
      end
    end
    
    def allowed?(path, required_permissions, username, groups)
      item = get_item(path)
      return false unless item
      permissions = item.permissions || 'rwxrwxrwx'
      if username.nil?
        perms = permissions[6,3]
      elsif item.owner == username
        perms = permissions[0,3]
      elsif groups.index(item.group)
        perms = permissions[3,3]
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