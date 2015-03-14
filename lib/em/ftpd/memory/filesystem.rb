module EM::FTPD::Memory
  class FileSystem
    @@filesystems = Hash.new
    def self.getFileSystemByName(name)
      if @@filesystems[name].nil?
        @@filesystems[name] = FileSystem.new
      end
      #puts "returning FileSystem named #{name}"
      return @@filesystems[name]
    end
    
    def initialize()
      @root = {
        '/' => Array.new
      }
      @contents = Hash.new
    end

    def exist?(path)
      is_dir(path) || is_file(path)
    end
    
    def list_files(path)
      @root[path] || []
    end
    
    def file_size(path)
      f = get_file(path)
      return false unless f
      f.size
    end
    
    def file_contents(path)
      # nil || false => false
      @contents[path] || false
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
    
    def create_file(path, data)
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
    
    def remove_file(path)
      if is_file(path)
        dirname = File.dirname(path)
        basename = File.basename(path)
        @root[dirname].reject! {|file| file.directory == false && file.name == basename}
        @contents.delete(path)
        return true
      end
      false
    end
    
    def delete_dir(path)
      if is_dir(path) && @root[path].empty?
        @root.delete(path)
        dirname = File.dirname(path)
        basename = File.basename(path)
        @root[dirname].reject! {|file| file.directory == true && file.name == basename}
        return true
      end
      false
    end
    
    def create_dir(path)
      if not exist?(path)
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
    
    def rename(from, to)
      return false if exist?(to)
      return false unless exist?(from)
      
      from_dirname = File.dirname(from)
      from_basename = File.basename(from)
      to_dirname = File.dirname(to)
      to_basename = File.basename(to)
      
      if from_dirname == to_dirname
        @root[from_dirname].find {|file| file.name == from_basename}.name = to_basename
      else
        entry = @root[from_dirname].reject! {|file| file.name == from_basename}
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

  end
end