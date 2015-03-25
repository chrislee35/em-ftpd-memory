require 'em-ftpd'
require 'digest/md5'

module EM::FTPD::Memory
  class InvalidPasswordAlgorithmError < StandardError; end
  class NoSuchUserError < StandardError; end
  class InvalidCredentialError < StandardError; end
  class ExpiredCredentialError < StandardError; end
  class MalformatedCredentialError < StandardError; end
  class ReplayCredentialError < StandardError; end
  class NoFurtherCredentialsAvailable < StandardError; end
  
  class TimedToken < Struct.new(:time, :token); end
  
  class User
    ATTRS = [:name, :algo, :credential, :groups]
    attr_accessor(*ATTRS)

    def initialize(options)
      options.each do |attr, value|
        self.send("#{attr}=", value)
      end
      @algo ||= (@credential) ? 'plain' : 'none'
      @groups ||= []
      raise ArgumentError.new("User requires a :name") unless @name
    end
  end

  class Authenticator
    @@realms = Hash.new
    TOKEN_VALIDITY_PERIOD = 300
    def self.getAuthenticatorByRealm(realm)
      if @@realms[realm].nil?
        @@realms[realm] = Authenticator.new
      end
      @@realms[realm]
    end
  
    def initialize
      @users = Hash.new
      @used_tokens = Array.new
    end
  
    def <<(user)
      unless self.respond_to?("#{user.algo}_authentication".to_sym)
        raise InvalidPasswordAlgorithmError.new
      end
      user.algo = "#{user.algo}_authentication".to_sym
      @users[user.name] = user
    end
  
    def delete(user)
      @users.delete(user.name)
    end
  
    def authenticate(username, credential)
      if @users[username].nil?
        raise NoSuchUserError.new
      end
      self.send(@users[username].algo, username, credential)
    end
    
    # this can be used for anonymous accounts
    def none_authentication(username, credential)
      return true
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
      if (time.to_i - Time.now.to_i).abs > TOKEN_VALIDITY_PERIOD
        raise ExpiredCredentialError.new
      else
        if Digest::MD5.hexdigest("#{seed}:#{time}:#{@users[username].credential}") == hash
          unless check_and_set_token(time.to_i, seed)
            raise ReplayCredentialError.new
          end
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
    
    def groups(username)
      if @users[username].nil?
        raise NoSuchUserError.new
      end
      @users[username].groups
    end
    
    private
    
    def check_and_set_token(time, token)
      # clean up stale tokens
      @used_tokens.reject! {|t| t.time < Time.now.to_i - TOKEN_VALIDITY_PERIOD}
      # check if token is replayed
      if @used_tokens.find {|t| t.time == time and t.token == token}
        return false
      end
      # add new token
      @used_tokens << TimedToken.new(time, token)
      true
    end
  end
end
