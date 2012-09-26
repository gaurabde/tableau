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
#
# -----------------------------------------------------------------------
# performance_data/lib/performance_on.rb
# -----------------------------------------------------------------------

require 'performance_models'
require 'erb'
require 'pathname'

module PerformanceOn
  class Config
    def get_binding
      binding
    end
  end

  def on?
    true
  end
  
  def connect(config)
    Performance::Base.establish_connection( config )
  end
  
  def write_tds( path, config )
    dbclasses = { 'postgresql' => 'postgres' }
    dbclass = config[ 'adapter' ]
    dbclass = dbclasses[ dbclass ] || dbclass

    tds_params = config.dup
    tds_params[ 'dbclass' ] = dbclass
    
    perfdir = Pathname.new(__FILE__).dirname
    tds_conf = ERB.new(( perfdir + 'Performance.rtds').read, nil, "<>")
    
    config = Config.new
    tds_params.each { |k,v| config.instance_variable_set("@#{k}".to_sym,v) }
    
    File.open(path,'wb') do |f|
      f.write(tds_conf.result(config.get_binding))
    end

  end

end
