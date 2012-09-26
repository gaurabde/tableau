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
require 'socket'
require 'delayed_retry'

module InstallerStatus

  def progress
    @status ||= StatusMethods.new
  end

  class StatusMethods
    def listeners
      @@listeners ||= []
    end

    def add_listener(listener)
      listeners << listener
    end

    def remove_listener(listener)
      listeners.delete listener
    end

    # Sets the main status message
    # This will also clear the detailed status if any
    def main(str)
      each_listener :main, str
    end

    # Sets the detailed status for the current step
    def details(str)
      each_listener :details, str
    end

    def steps(total_steps)
      each_listener :steps, total_steps
    end

    def add_steps(count)
      each_listener :add_steps, count
    end

    def increment
      each_listener :increment
    end

    # Sets the error status and maxes out the steps
    def error(str)
      each_listener :error, str
    end

    private

    def each_listener(sym, *args)
      listeners.each do |l|
        l.send(sym, *args) if l.respond_to? sym
      end
    end
  end
end

# A class that observes status events and writes those to the
# progress monitor dialog via a socket
class StatusMonitor

  include InstallerStatus

  SERVER_REPOSITORY_NAME = 'Tableau Server Repository'

  # Factory method to initialize the connection to the progress dialog
  def self.start(opts = {})
    if opts[:start]
      close_firewall = launch_dialog
    else
      close_firewall = false
    end

    socket = nil
    begin
      delayed_retry(:tries => 6, :delay => 0.5, :exceptions => SystemCallError) do
          socket = TCPSocket.new('localhost', AppConfig.progress.port)
      end
    rescue SystemCallError
    end

    return nil if socket.nil?

    socket = Net::BufferedIO.new(socket)
    sm = StatusMonitor.new(socket, close_firewall)
    sm.progress.add_listener(sm)
    sm.progress.steps(opts[:steps]) if opts[:steps]
    return sm
  end

  # this is used from the backgrounder when it needs to connect to an already
  # running instance of the dialog. If the dialog isn't running, this method
  # will fail quickly and return nil.
  def self.connect
    begin
      socket = TCPSocket.new('localhost', AppConfig.progress.port)
    rescue
    end

    return nil if socket.nil?

    socket = Net::BufferedIO.new(socket)
    sm = StatusMonitor.new(socket, false)
    sm.progress.add_listener(sm)
    return sm
  end
  def self.launch_dialog
    # punch a hole in the firewall
    close_firewall = Service.open_firewall(Cfg.app.tabrepo, SERVER_REPOSITORY_NAME)

    cmd = [Cfg.app.tabrepo, '-c', Cfg.config.name, "--client=true", "--classpath", Cfg.app.tabprogress, 'com.tableausoftware.progress.Dialog', AppConfig.progress.port]
    SetTmp.with_saved_tmp do
      Run.command(cmd, {:fork => true})
    end
    return close_firewall
  end

  attr_reader :socket
  attr_writer :close_firewall

  def initialize (socket, close_firewall)
    @socket = socket
    @close_firewall = close_firewall
  end

  def write(str, ignore_response = false)
    return if socket.nil?

    socket.writeline str

    return if ignore_response

    rsp = socket.read(4)
    if rsp != "OK\r\n"
      logger.info("invalid response from server");
      @socket = nil;
    end
  rescue SystemCallError, IOError => e
    logger.info("Error communicating with progress monitor: #{e}") unless ignore_response
    @socket = nil
  end

  def main(str)
    write("status: #{str}")
  end

  def details(str)
    write("details: #{str}")
  end

  def add_steps(count)
    write("add-steps: #{count}")
  end

  def steps(count)
    write("steps: #{count}")
  end

  def increment
    write("step-increment")
  end

  def close
    progress.remove_listener(self)
    write("exit", true)
    Service.close_firewall(Cfg.app.tabrepo, SERVER_REPOSITORY_NAME) if @close_firewall
  end

  def bye
    progress.remove_listener(self)
    write('bye', true)
  end

  def error(str)
    write("error: #{str}")
  end
end
