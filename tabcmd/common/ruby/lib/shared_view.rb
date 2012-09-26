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
# app/models/shared_view.rb
# -----------------------------------------------------------------------

require 'guid_maker'

class SharedView < ActiveRecord::Base
  belongs_to :parent,    :class_name => 'SharedView', :foreign_key => 'parent_id'
  belongs_to :base_view, :class_name => 'View',       :foreign_key => 'base_view_id'
  belongs_to :creator,   :class_name => 'User',       :foreign_key => 'creator_id'
  #B50247: When removing a shared view, also remove its corresponding record in the big_texts table
  belongs_to :tcv,       :class_name => 'BigText',    :foreign_key => 'big_text_id',  :dependent => :destroy

  def initialize(*args)
    super
    self.guid = GuidMaker.new(9).generate if self.guid.nil?
  end

end
