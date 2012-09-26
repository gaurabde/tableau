# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
# Patents Pending.
#
# common/ruby/lib/product_version.rb
# -----------------------------------------------------------------------

require 'hierstruct'
require 'stringio'
require 'date'

module ProductVersionUtil
  def self.make_product_version(fn)
    pv = HierStruct.new

    pv.file = fn

    version_regexps = [ [ /VERSION_RSTR *"(.*?)"/,           'rstr' ],
                        [ /VERSION_STR *"(.*?)"/,            'short' ],
                        [ /VERSION_EXTERNAL_STR *"(.*?)"/,   'external' ],
                        [ /VERSION_CODENAME *_T\("(.*?)"\)/, 'codename' ],
                        [ /VERSION_ISBETA *(.*?)\s*$/,       'isbeta' , lambda { |x| x.to_i == 1 } ] ]

    StringIO.new(File.read(pv.file)).each_line do |line|
      match = nil
      vr = version_regexps.find { |reg| match = reg.first.match(line) }
      next unless match
      pv[vr[1]] = vr[2] ? vr[2].call(match[1]) : match[1]
    end

    pv.array = pv.rstr.split('.')
    pv.number = pv.array.join(', ')
    pv.current = pv.short == "0.0" ? pv.codename : pv.short

    pv << :full
    pv.full.array = pv.array.clone
    pv.full.array[0] = pv.codename if pv.short == "0.0"
    pv.full.str = pv.full.array.join('.')

    pv << :build
    pv.build.array = pv.array.slice(1..-1).map{ |v| v.to_i }

    # If this is a development build, then just use today as the build date.
    if pv.build.array == [0,0,0]
      pv.build.date = Date.today
    else
      # Transform the array format; The build date is encoded in the three integers as year (0 == 2000), MMDD, HHMM.
      # We want [YYYY, MM, DD] instead.
      pv.build.date_array = [2000+pv.build.array[0], pv.build.array[1] / 100, pv.build.array[1] % 100]
      begin
        # NOTE: The asterisk below is REQUIRED
        pv.build.date = Date.new(*pv.build.date_array)
      rescue StandardError => err
        # This is fatal
        raise "Cannot parse this date #{config.version.rstr}.  The array: #{pv.build.date_array.join(",")}.  Error: #{err}"
      end
    end
    pv
  end
end

# quick attempt to satisfy dev-tree server + war-file server
product_version = nil
begin
  product_version = ProductVersionUtil.make_product_version(File.expand_path(__FILE__+'/../../../../../tableau-1.3/res/VersionConstants.h'))
rescue
  begin
    product_version = ProductVersionUtil.make_product_version(File.expand_path('common/ruby/lib/VersionConstants.h'))
  rescue
    begin
      product_version = ProductVersionUtil.make_product_version(File.expand_path('VersionConstants.h', File.dirname(__FILE__)))
    rescue
      $stderr.puts("unable to resolve product version")
    end
  end
end
ProductVersion = product_version
