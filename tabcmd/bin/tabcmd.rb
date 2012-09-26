#!/usr/bin/env ruby
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

require 'rubygems'

require 'active_support/core_ext'

# AppConfig setup
$LOAD_PATH << File.expand_path(__FILE__ + '/../../../common/ruby/lib')
$LOAD_PATH << File.expand_path(__FILE__ + '/../../common/ruby/lib')

require 'settmp'
$saved_environment = {}

module Tabcmd
  unless self.const_defined?(:Test)
    Test = nil
  end
end

# Tabcmd library
$LOAD_PATH << File.expand_path(__FILE__+'/../../lib')
require File.expand_path(__FILE__+'/../../lib/tabcmd.rb')

MultiCommand::CommandManager.load_commands

module Tabcmd
  class << self
    def run(args)
      MultiCommand::CommandManager.dispatch(args)
    end
  end
end

unless Tabcmd::Test
  Tabcmd.run(ARGV)
end
