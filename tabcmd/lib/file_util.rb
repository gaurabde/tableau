# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2012 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'relative_path'

class FileUtil
  # B39599 - helper method - converting UTF-16 file's encoding into UTF-8.
  def self.get_file_ensure_utf8(input_file)
    supported_encodings = ['utf-8', 'ascii', 'iso-8859-1', 'iso-8859-2', 'windows-1252']
	binary = nil

    encoding = nil

    File.open(RelativePath.fix_path(input_file), "rb") do |f|
      binary = f.read
    end
    encoding = CharDet.detect(binary)
    encoding_name = (encoding["encoding"]).downcase
    # when input file is UTF8 or subset of it (ASCII/ISO-8859-1/ISO-8859-2/WINDOWS-1252) we skip the conversion
    if supported_encodings.include?(encoding_name)
      return binary
    end

    # converting UTF-16 encodings into UTF-8, using chunks of 512 bytes (due to Ruby bug: http://redmine.ruby-lang.org/issues/3448 )
    if ( encoding_name == 'utf-16le' || encoding_name == 'utf-16be' )
      contents = ""
      begin
        i = 0
        chunksize = 512
        chunk = binary[i, chunksize]
        while (chunk && chunk.size > 0)
          contents << Iconv.conv("UTF-8", encoding["encoding"], chunk)
          i += chunksize
          chunk =binary[i, chunksize]
        end
      rescue Iconv::BrokenLibrary => err
        logger.error "Error converting file from UTF-16 to UTF-8."  # B40852 reword error per Wordage
        return "" # error while trying to convert encoding - return empty string
      rescue Iconv::Failure => err
        logger.error "#{input_file} has invalid encoding."
        return "" # error while trying to convert encoding - return empty string
      end
    else
      logger.error "File encoding is not supported. Convert the file to UTF-16 or UTF-8 and try again."  # B40852 reword error per Wordage
      return "" # error while trying to convert encoding - return empty string
    end
    return contents
  end
end