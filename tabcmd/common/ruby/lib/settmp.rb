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

require 'pathname'

module SetTmp
  extend self
  
  def normalize_pathsep(dir)
    dir.to_s.gsub('/','\\')
  end

  def tmp_set?
    defined?($saved_environment)
  end

  def tmpdir=(tmpdir)
    tmpdir = Pathname.new(tmpdir)
    $saved_environment ||= {}
    %w(TMPDIR TEMP TMP).each do |var|
      $saved_environment[var] ||= ENV[var]
    end
    
    tmpdir.mkpath unless tmpdir.directory?
    ENV['TMPDIR'] = ENV['TEMP'] = ENV['TMP'] = SetTmp.normalize_pathsep(tmpdir)
  end
  
  def with_saved_tmp
    if defined?($saved_environment)
      tmpdir = ENV['TMP']
      begin
        %w(TMPDIR TEMP TMP).each do |var|
          ENV[var] = $saved_environment[var]
        end
        yield
      ensure
        ENV['TMPDIR'] = ENV['TEMP'] = ENV['TMP'] = SetTmp.normalize_pathsep(tmpdir)
      end
    else
      yield
    end
  end
end
