require 'em-ftpd'
require 'digest/md5'

module EM::FTPD::Memory
  class User < Struct.new(:name, :credential); end
  class InvalidPasswordAlgorithm < StandardError; end
  class NoSuchUserError < StandardError; end
  class InvalidCredentialdError < StandardError; end
  class ExpiredCredentialError < StandardError; end

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
      # this prevents someone from setting "delete" as the authentication algorithm
      algo = "#{@pwalgo}_authentication".to_sym
      if self.respond_to?(algo)
        self.send(algo, username, credential)
      else
        raise InvalidPasswordAlgorithmError.new
      end
    end
  
    def plain_authentication(username, credential)
      if @users[username].credential != credential
        raise InvalidCredentialdError.new
      else
        return true
      end
    end
  
    def timed_md5_authentication(username, credential)
      seed, time, hash = credential.split(/:/, 3)
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
