unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'digest/md5'
include EM::FTPD::Memory

class TestAuthenticator < Minitest::Test
  def test_invalid_pwalgo
    assert_raises(InvalidPasswordAlgorithmError) do
      auth = Authenticator.getAuthenticatorByRealm(__method__)
      auth << User.new(:name => "test", :algo => "nogood", :credential => "test")
    end
  end
    
  def test_plain_login
    auth = Authenticator.getAuthenticatorByRealm(__method__)
    auth << User.new(:name => "test", :algo => "plain", :credential => "test")
    assert_raises(NoSuchUserError) do
      auth.authenticate("jerk", "noway")
    end
    
    assert_raises(InvalidCredentialError) do
      auth.authenticate("test", "noway")
    end
    
    assert(auth.authenticate("test", "test"))
  end
  
  def test_time_based_login
    auth = Authenticator.getAuthenticatorByRealm(__method__)
    auth << User.new(:name => "test", :algo => "timed_md5", :credential => "test")
    assert_raises(NoSuchUserError) do
      auth.authenticate("jerk", "noway")
    end
    
    assert_raises(MalformatedCredentialError) do
      auth.authenticate("test", "noway")
    end
    
    assert_raises(MalformatedCredentialError) do
      auth.authenticate("test", "test")
    end
    
    time = Time.now.to_i - 1200
    seed = "this is a random seed"
    expired_hash = Digest::MD5.hexdigest("#{seed}:#{time}:test")
    expired_cred = "#{seed}:#{time}:#{expired_hash}"
    
    assert_raises(ExpiredCredentialError) do
      auth.authenticate("test", expired_cred)
    end
    
    time = Time.now.to_i
    seed = "this is a random seed"
    invalid_hash = Digest::MD5.hexdigest("#{seed}:#{time}:wrong")
    invalid_cred = "#{seed}:#{time}:#{invalid_hash}"

    assert_raises(InvalidCredentialError) do
      auth.authenticate("test", invalid_cred)
    end

    time = Time.now.to_i
    seed = "this is a random seed"
    valid_hash = Digest::MD5.hexdigest("#{seed}:#{time}:test")
    valid_cred = "#{seed}:#{time}:#{valid_hash}"
    
    assert(auth.authenticate("test", valid_cred))
    
    assert_raises(ReplayCredentialError) do
      auth.authenticate("test", valid_cred)
    end
    
  end
  
  def test_otp_login
    auth = Authenticator.getAuthenticatorByRealm(__method__)
    auth << User.new(:name => "test", :algo => "otp", :credential => "test1\ntest2\ntest3\ntest4\ntest5")
    assert_raises(NoSuchUserError) do
      auth.authenticate("jerk", "noway")
    end
    
    assert_raises(InvalidCredentialError) do
      auth.authenticate("test", "wrong")
    end
    
    1.upto(4) do |i|    
      assert(auth.authenticate("test","test#{i}"))
    
      assert_raises(InvalidCredentialError) do
        auth.authenticate("test", "test#{i}")
      end
    end
    
    assert(auth.authenticate("test","test5"))
    assert_raises(NoFurtherCredentialsAvailable) do
      auth.authenticate("test", "test5")
    end
  end
  
  def test_anonymous_login
    auth = Authenticator.getAuthenticatorByRealm(__method__)
    auth << User.new(:name => "anonymous")
    assert_raises(NoSuchUserError) do
      auth.authenticate("jerk", "noway")
    end
    
    assert(auth.authenticate("anonymous","test@example.com"))
  end
end