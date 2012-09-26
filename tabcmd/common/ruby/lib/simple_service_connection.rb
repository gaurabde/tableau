# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
# -----------------------------------------------------------------------

require 'delayed_retry'
require 'local_ip_address'

class SimpleServiceConnection

  # Create a connection to a service. Any connection must be closed.
  # A successful creation and close indicates a service is up.
  # Use Socket.getaddrinfo because open and connect must match in IPv4/IPv6 family
  # Throws StandardError
  def initialize(host, port, timeout_in_microsec=50000, timeout_in_sec=0)
    addr = Socket.getaddrinfo(host, nil)
    @socket = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)
    timout = [timeout_in_sec, timeout_in_microsec].pack("I_2")
    if ! @socket.nil?
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, timout)
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, timout)
      @socket.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
    end
  end

  # Close the connection if possible. Do not throw.
  def close
    if ! @socket.nil?
      @socket.close rescue nil
    end
  end
end
