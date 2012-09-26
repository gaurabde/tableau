require 'multicommand'
module MultiCommand

  class HiddenCommand < MultiCommand::Command
    def initialize
      super
    end

    def list?
      false
    end
  end

end
