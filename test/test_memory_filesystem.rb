unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'

include EM::FTPD::Memory

class TestMemoryFilesystem < Minitest::Test
  def test_filesystem_instance_retrieval
    fs = FileSystem.getFileSystem(__method__)
    fs2 = FileSystem.getFileSystem(__method__)
    assert(fs.equal?(fs2))
    FileSystem.destroyFileSystem(__method__)
    fs2 = FileSystem.getFileSystem(__method__)
    refute(fs.equal?(fs2))
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_file_creation
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_file("/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/helper.rb"))
    refute(fs.is_dir?("/helper.rb"))
    assert(fs.is_file?("/helper.rb"))
    assert_equal(169, fs.file_size("/helper.rb"))
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_file_deletion
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_file("/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/helper.rb"))
    refute(fs.is_dir?("/helper.rb"))
    assert(fs.is_file?("/helper.rb"))
    assert_equal(169, fs.file_size("/helper.rb"))
    assert(fs.delete_file("/helper.rb"))
    refute(fs.exist?("/helper.rb"))
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_create_directory
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    
    assert(fs.create_dir("/pub"))
    assert(fs.exist?("/pub"))
    assert(fs.is_dir?("/pub"))
    refute(fs.is_file?("/pub"))
    
    assert(fs.create_file("/pub/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/pub/helper.rb"))
    assert_equal(169, fs.file_size("/pub/helper.rb"))
    assert(fs.delete_file("/pub/helper.rb"))
    refute(fs.exist?("/pub/helper.rb"))
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_delete_directory
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_dir("/pub"))
    assert(fs.exist?("/pub"))
    assert(fs.is_dir?("/pub"))
    refute(fs.is_file?("/pub"))
    
    assert(fs.create_file("/pub/helper.rb", "test/helper.rb", "root"))
    assert(fs.exist?("/pub/helper.rb"))
    assert_equal(169, fs.file_size("/pub/helper.rb", "root"))
    refute(fs.delete_dir("/pub", "root"))
    assert(fs.delete_file("/pub/helper.rb", "root"))
    refute(fs.exist?("/pub/helper.rb"))
    assert(fs.delete_dir("/pub", "root"))
    refute(fs.exist?("/pub"))
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_file_rename
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_dir("/pub"))
    assert(fs.exist?("/pub"))
    assert(fs.is_dir?("/pub"))
    refute(fs.is_file?("/pub"))
    
    assert(fs.create_file("/pub/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/pub/helper.rb"))
    assert_equal(169, fs.file_size("/pub/helper.rb"))
    assert(fs.rename("/pub/helper.rb", "/pub/helper.txt"))
    refute(fs.exist?("/pub/helper.rb"))
    assert(fs.exist?("/pub/helper.txt"))
    assert_equal(169, fs.file_size("/pub/helper.txt"))
    
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_file_move_between_directories
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_dir("/pub"))
    assert(fs.exist?("/pub"))
    assert(fs.is_dir?("/pub"))
    refute(fs.is_file?("/pub"))
    assert(fs.create_dir("/pub2"))
    assert(fs.exist?("/pub2"))
    assert(fs.is_dir?("/pub2"))
    refute(fs.is_file?("/pub2"))
    
    assert(fs.create_file("/pub/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/pub/helper.rb"))
    assert_equal(169, fs.file_size("/pub/helper.rb"))
    assert(fs.rename("/pub/helper.rb", "/pub2/helper.txt"))
    refute(fs.exist?("/pub/helper.rb"))
    assert(fs.exist?("/pub2/helper.txt"))
    assert_equal(169, fs.file_size("/pub2/helper.txt"))
    
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_rename_directory
    fs = FileSystem.getFileSystem(__method__)
    assert(fs.set_permissions("/", "rwxrwxrwx", "root"))
    assert(fs.create_dir("/pub"))
    assert(fs.exist?("/pub"))
    assert(fs.is_dir?("/pub"))
    refute(fs.is_file?("/pub"))
    assert(fs.create_dir("/pub2", "root"))
    assert(fs.exist?("/pub2"))
    assert(fs.is_dir?("/pub2"))
    refute(fs.is_file?("/pub2"))
    assert(fs.create_file("/pub3", "test/helper.rb"))
    assert(fs.exist?("/pub3"))
    refute(fs.is_dir?("/pub3"))
    assert(fs.is_file?("/pub3"))
    assert_equal(169, fs.file_size("/pub3"))
    
    refute(fs.rename("/pub", "/pub2"))
    refute(fs.rename("/pub", "/pub3"))
    assert(fs.delete_file("/pub3", "root"))
    assert(fs.rename("/pub", "/pub3"))
    
    FileSystem.destroyFileSystem(__method__)
  end
  
  def test_file_permissions
    fs = FileSystem.getFileSystem(__method__)
    assert_raises(InvalidPermissionsError) do
      fs.set_permissions("/", "rwx", "root")
    end
    
    refute(fs.set_permissions("/", "rwxr.xr.x", "nobody"))
    assert(fs.set_permissions("/", "rwxr.xr.x", "root"))
    refute(fs.create_dir("/pub"))
    refute(fs.exist?("/pub"))
    assert(fs.create_dir("/pub", "root"))
    assert(fs.exist?("/pub"))
    assert(fs.create_file("/pub/helper.rb", "test/helper.rb"))
    assert(fs.exist?("/pub/helper.rb"))
    assert(fs.delete_file("/pub/helper.rb"))
    refute(fs.exist?("/pub/helper.rb"))
    assert(fs.set_permissions("/pub", 'rwxr.xr.x', "root"))
    refute(fs.create_file("/pub/helper.rb", "test/helper.rb"))
    refute(fs.exist?("/pub/helper.rb"))
    assert(fs.create_dir("/pub/pub2","root"))
    assert(fs.create_dir("/pub/pub2/pub3","root"))
    assert(fs.create_dir("/pub/pub2/pub3/pub4","root"))
    assert(fs.set_permissions("/pub/pub2/pub3", "rwx......", "root"))
    assert_equal(0, fs.list_files("/pub/pub2/pub3").length)
    assert_equal(1, fs.list_files("/pub/pub2/pub3", "root").length)
    refute(fs.create_file("/pub/pub2/pub3/pub4/helper.rb", "test/helper.rb"))
    assert(fs.create_file("/pub/pub2/pub3/pub4/helper.rb", "test/helper.rb", "root"))
    refute(fs.file_size("/pub/pub2/pub3/pub4/helper.rb"))
    assert_equal(169, fs.file_size("/pub/pub2/pub3/pub4/helper.rb", "root"))


    assert_equal(0, fs.list_files("/pub/pub2/pub3", "jem").length)
    refute(fs.file_size("/pub/pub2/pub3/pub4/helper.rb", "jem"))
    assert(fs.set_owner("/pub/pub2/pub3", "jem", "root"))
    assert_equal(1, fs.list_files("/pub/pub2/pub3", "jem").length)
    assert_equal(169, fs.file_size("/pub/pub2/pub3/pub4/helper.rb", "jem"))

    assert(fs.set_permissions("/pub/pub2", "rwx......", "root"))
    # jem owns pub3, but should be denied since she can't traverse pub2
    refute(fs.set_permissions("/pub/pub2/pub3", "rwx......", "jem"))
    assert(fs.set_permissions("/pub/pub2", "rwxr.xr.x", "root"))
    assert(fs.set_permissions("/pub/pub2/pub3", "rwx......", "jem"))
    
    assert(fs.create_dir("/group_test", "root"))
    assert(fs.set_group("/group_test", "test", "root", ["test"]))
    assert(fs.set_permissions("/group_test", "rwxr.x...", "root"))
    assert(fs.create_file("/group_test/test", "test/helper.rb", "root"))
    assert_equal(0, fs.list_files("/group_test", "jem", ["nottest"]).length)
    assert_equal(1, fs.list_files("/group_test", "jem", ["test", "other", "punkbands"]).length)
    
  end

end