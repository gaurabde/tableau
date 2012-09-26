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
# performance_data/lib/performance_models.rb
# -----------------------------------------------------------------------

module Performance
  class Base < ActiveRecord::Base
    self.abstract_class = true
  end

  # Your models go here.
  
  class Component < Base
  end

  class Task < Base
  end

  class Session < Base
  end

  class Request < Base
  end

  class Detail < Base
  end

  class Fact < Base
  end

end
