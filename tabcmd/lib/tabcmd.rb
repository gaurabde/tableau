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

TABCMD_LIB = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << TABCMD_LIB
$LOAD_PATH.uniq!

require 'product_version'
require 'logging'
require 'hierstruct'
require 'uri'
require 'pathname'
require 'relative_path'

Dir[File.expand_path(__FILE__+'/../*.rb')].sort.each do |f|
  require f[TABCMD_LIB.length+1..-4] unless f =~ /tabcmd\.rb$/
end

XML_API_VERSION = '0.3'

Server = ServerInfo.new

# Tabcmd doesn't use the whole configuration structure of wgapp/vqlapp,
# but http_util expects an AppConfig.  For now it's simplest to create
# an empty one
AppConfig = HierStruct.new

module Tabcmd
  #copied from wgapp
  UNSAFE_ID_REGEXP = /[&+\.,%;\/?]/
  #two pass, inner maps things which aren't usually encoded via regexp above this line
  #           outer is standard uri escaping
  def self.encode_id(name)
    URI.escape(URI.escape( name, UNSAFE_ID_REGEXP))  unless name.nil?
  end
end
