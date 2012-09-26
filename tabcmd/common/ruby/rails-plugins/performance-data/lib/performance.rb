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

require 'performance_on'
require 'performance_off'

module Performance

  def Performance.init(app_config)
    # Set up the performance logging
    if app_config['logging.performance.enabled']
      puts "== Enabling performance logging"
      class << self
        include PerformanceOn
      end
      retval = app_config.logging.performance.connection.table
      connect( retval )
      retval
    else
      class << self
        include PerformanceOff
      end
      {}
    end
  end


  ## dlion Jan 08
  ## helper routines to run manually from a wgconsole (or wgapp script/console) session
  ## mark_events looks for spans of performance rows between a "view/show" and a "session/errors", grouping them if ungrouped.
  ## adjust_time attempts to move the start of each "event group" to the beginning of the epoch, trying for apples to apples comparison and making alternate viz's possible.

  def Performance.mark_events()
    beginnings = Performance::Fact.find(:all, :conditions => "task = 'show' AND controller = 'views' AND event IS NULL", :order => "request_id")

    event_max = Performance::Fact.connection.execute("SELECT max(event) AS max_event FROM facts")[0]['max_event'].to_i

    beginnings.each do |starting_row|
      ending_row = Performance::Fact.connection.execute("SELECT min(id) AS min_id FROM facts WHERE id > #{starting_row[:id]} AND controller = 'sessions' AND task ='errors'")[0]['min_id'].to_i
      unless (0 == ending_row)
        start_time = starting_row[:start_time]
        end_time = Performance::Fact.find(:first, :conditions => "id = #{ending_row}")[:end_time]
        Performance::Fact.connection.execute("UPDATE facts SET event = #{event_max + 1} WHERE start_time >= '#{starting_row[:start_time]}' AND end_time <= '#{end_time}'")
      end
      event_max += 1
    end

  end

  def Performance.adjust_time()
    all_events = Performance::Fact.connection.execute("SELECT distinct(event) AS distinct_event FROM facts").collect{|t| t['distinct_event']}.compact.collect{|t| t.to_i}
    all_events.each do |event|
      first_start_time = DateTime.parse(Performance::Fact.connection.execute("SELECT start_time FROM facts WHERE task = 'show' AND controller = 'views' AND event = #{event} ORDER BY start_time LIMIT 1")[0]['start_time'])
      sub_events = Performance::Fact.find(:all, :conditions => "event = #{event}")
      sub_events.each do |sub_event|
        sub_event.adjusted_start_time = sub_event.start_time - first_start_time
        sub_event.save!
      end
    end

  end

end

