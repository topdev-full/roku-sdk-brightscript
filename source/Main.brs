'Main.brs

sub Main()
    print "Starting Roku TCP Tunnel SDK..."
    tunnel = getTcpTunnel()
    tunnel.start()
end sub

