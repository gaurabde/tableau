## when invoked via tablaunchjava, the current-working-directory may (likely) be different that where the user invoked tabcmd
## This Module and helper-routine can fixup relative paths to be from the original launch-dir

require 'java'

module RelativePath
  def self.fix_path(incoming)
    return nil unless incoming
    p = Pathname.new(incoming)
    return incoming if p.absolute?
    tableau_working_dir = java.lang.System.get_property("tableau.working.dir")
    if tableau_working_dir
      return File.expand_path(incoming, tableau_working_dir)
    end
    return incoming
  end
end
