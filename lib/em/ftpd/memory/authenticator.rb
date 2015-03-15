require 'em-ftpd'
require 'digest/md5'

module EM::FTPD::Memory
  class User < Struct.new(:name, :credential); end
  class InvalidPasswordAlgorithmError < StandardError; end
  class NoSuchUserError < StandardError; end
  class InvalidCredentialError < StandardError; end
  class ExpiredCredentialError < StandardError; end
  class MalformatedCredentialError < StandardError; end
  class NoFurtherCredentialsAvailable < StandardError; end

  class Authenticator
    @@realms = Hash.new
    def self.getAuthenticatorByRealm(realm, options = {})
      if @@realms[realm].nil?
        @@realms[realm] = Authenticator.new(options)
      end
      #puts "returning Authenticator of realm #{realm}"
      @@realms[realm]
    end
  
    def initialize(options = {})
      @users = Hash.new
      @pwalgo = options["pwalgo"] || "plain"
      @pwalgo = "#{@pwalgo}_authentication".to_sym
      unless self.respond_to?(@pwalgo)
        raise InvalidPasswordAlgorithmError.new
      end
    end
  
    def <<(user)
      @users[user.name] = user
    end
  
    def delete(user)
      @users.delete(user.name)
    end
  
    def authenticate(username, credential)
      if @users[username].nil?
        raise NoSuchUserError.new
      end
      self.send(@pwalgo, username, credential)
    end
  
    def plain_authentication(username, credential)
      if @users[username].credential != credential
        raise InvalidCredentialError.new
      else
        return true
      end
    end
  
    def timed_md5_authentication(username, credential)
      seed, time, hash = credential.split(/:/, 3)
      if hash.nil? or hash.length != 32
        raise MalformatedCredentialError.new
      end
      if (time.to_i - Time.now.to_i).abs > 300
        raise ExpiredCredentialError.new
      else
        if Digest::MD5.hexdigest("#{seed}:#{time}:#{@users[username].credential}") == hash
          return true
        else
          raise InvalidCredentialError.new
        end
      end
    end
    
    def otp_authentication(username, credential)
      passwords = @users[username].credential.split(/\n/)
      if passwords.empty?
        raise NoFurtherCredentialsAvailable.new
      end
      current_password = passwords.shift
      if credential == current_password
        @users[username].credential = passwords.join("\n")
        return true
      else
        raise InvalidCredentialError.new        
      end
    end
  end
end
