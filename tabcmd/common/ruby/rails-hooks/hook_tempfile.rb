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
#
# Provide a mechanism for Tempfile to abandon its lifecycle management of the file (on disk)
# so that our custom mod_xsendfile apache module can delete it after delivery.
# -----------------------------------------------------------------------
#
# in JRuby, Tempfile is a java object

class Tempfile
  attr_accessor :tmpname

  # Closes and unlinks the file.
  def abandon!
    orig_path = self.path
    self.close(false) # don't unlink
    moved_path = orig_path + 'xx'  #should we make some guarantee about path length?
    FileUtils.mv(orig_path, moved_path);
    return moved_path
  end
end

