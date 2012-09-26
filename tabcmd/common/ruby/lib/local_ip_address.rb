require 'socket'
class LocalIpAddress
  def initialize(appcfg)
    # default IP to use if there are no other workers
    # this may not return expected answer if there are multiple network adapters

    local_ip = IPSocket.getaddress(Socket.gethostname)
    if appcfg.nil? or appcfg['worker.hosts'].nil?
      @local_ip = local_ip
      return
    end
    workers = appcfg['worker.hosts'].split(/, */)
    if workers.size < 2
      @local_ip = local_ip
      return
    end
    # Get the local ip address based on the network adaptor used to reach the workers
    # Because UDP is stateless, no connection is made in the following block
    # but kernel state is created based on the worker's address
    # The last value of the connection is the IP address, irrespective of do_not_reverse_lookup
    begin
      UDPSocket.open do |s|
        s.connect workers.last(), 1
        @local_ip = s.addr.last
      end
    rescue
      @local_ip = local_ip
    end
  end
  
  def get_ip
    @local_ip.to_s
  end
  
  def to_s
    @local_ip.to_s
  end
end