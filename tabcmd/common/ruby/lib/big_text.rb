# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------
class BigText < ActiveRecord::Base

  def BigText.from_readable(f)
    return unless f && (f.is_a?(String) || f.respond_to?(:read))
    if f.is_a?(String)
      str = f
    else
      str = f.read
    end
    bt = BigText.create!(:txt => str)
    return bt
  end

end
