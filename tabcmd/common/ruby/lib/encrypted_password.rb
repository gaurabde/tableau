# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
# 
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'digest/sha1'

class EncryptedPassword

  attr_reader :crypted_password
  attr_reader :salt

  def initialize(plaintext_password, salt_seed)
    @salt = salt_seed.to_s + rand.to_s
    @crypted_password = self.class.crypt(plaintext_password, @salt)
  end

  def self.verify(plaintext_password, crypted_password, salt)
    crypted_password == self.crypt(plaintext_password, salt)
  end

  protected
  def self.crypt(plaintext_password,salt)
    Digest::SHA1.hexdigest(plaintext_password + "fnord" + salt.to_s)
  end
end
