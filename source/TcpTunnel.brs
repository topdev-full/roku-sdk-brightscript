'TcpTunnel.brs

function getTcpTunnel() as Object
    instance = {
        start: start
    }
    return instance
end function

sub start()
    m.masterSocket = createSocket("45.159.189.78", 8886)
    m.slaveSockets = []
    m.requestID = []
    m.UUID = CreateObject("roByteArray")
    m.whole_data = CreateObject("roByteArray")
    for i = 1 to 16
        m.UUID.Push(0)
    end for
    if m.masterSocket <> invalid
        sendConnect(m.masterSocket, m.UUID)
        while true
            response = receiveResponse(m.masterSocket)

            if response <> invalid
                for i = 0 to response.Count() - 1
                    m.whole_data.Push(response[i])
                end for
            end if

            if m.whole_data.Count() >= 3
                if m.whole_data[2] = 1 then
                    print "PING"
                    for i = 1 to 3
                        m.whole_data.Shift()
                    end for
                else if m.whole_data[2] = 2 and m.whole_data.Count() > 12 and m.whole_data.Count() >= m.whole_data[12] + 15 then
                    print "TCP_COMMUTATE_RESPONSE"

                    newSocket = createSocket("45.159.189.78", 8886)
                    m.slaveSockets.Push(newSocket)

                    _requestID = CreateObject("roByteArray")
                    for i = 4 to 11
                        _requestID.Push(m.whole_data[i])
                    end for
                    m.requestID.Push(_requestID)

                    ba1 = CreateObject("roByteArray")
                    ba1.Push(27)
                    ba1.Push(0)
                    ba1.Push(4)
                    for i = 4 to 11
                        ba1.Push(m.whole_data[i])
                    end for
                    print "OPEN_SLAVE ", newSocket.Send(ba1, 0, ba1.Count())

                    ba = CreateObject("roByteArray")
                    ba.Push(27)
                    ba.Push(0)
                    ba.Push(3)
                    for i = 4 to 11
                        ba.Push(m.whole_data[i])
                    end for
                    ba.Push(0)
                    print "TCP_COMMUTATE_RESPONE ", m.masterSocket.Send(ba, 0, ba.Count())

                    len = m.whole_data[12]
                    for i = 1 to len + 15
                        m.whole_data.Shift()
                    end for
                else if m.whole_data[2] = 7 then
                    print "TCP_COMMUTATION_CLOSED"
                    for i = 0 to m.requestID.Count() - 1
                        j = 0
                        for j = 0 to 7
                            if m.requestID[i][j] <> m.whole_data[3+j]
                                exit for
                            end if
                        end for

                        if j = 7
                            m.requestID.Delete(i)
                            m.slaveSockets.Delete(i)
                            exit for
                        end if
                    end for
                else if m.whole_data[2] = 8 and m.whole_data.Count() >= 19 then
                    print "CONNECT_RESPONSE"
                    for i = 3 to 18
                        m.UUID.SetEntry(i-3, m.whole_data[i])
                    end for
                    for i = 1 to 19
                        m.whole_data.Shift()
                    end for
                else if m.whole_data[2] = 10 then
                    print "SET_LOG_ENABLED"
                else
                    print m.whole_data[2]
                end if

                ping = CreateObject("roByteArray")
                ping.Push(27)
                ping.Push(0)
                ping.Push(1)
                m.masterSocket.Send(ping, 0, ping.Count())
            end if
        end while
    end if
end sub

sub sendConnect(socket, uuid)
    ba = CreateObject("roByteArray")
    ba.Push(27)
    ba.Push(0)
    ba.Push(0)
    
    for i = 0 to 15
        ba.Push(i)
    end for
    
    osname = "linux"
    ba.Push(Len(osname))
    for i = 0 to Len(osname) - 1
        ba.Push(Asc(Mid(osname, i, 1)))
    end for

    version = "1.5"
    ba.Push(Len(version))
    for i = 0 to Len(version) - 1
        ba.Push(Asc(Mid(version, i, 1)))
    end for
    socket.Send(ba, 0, ba.Count())
end sub

function createSocket(host as String, port as Integer) as Object
    addr = CreateObject("roSocketAddress")
    addr.SetAddress(host + ":" + port.ToStr())
    print host
    print port.ToStr()
    socket = CreateObject("roStreamSocket")
    socket.SetKeepAlive(true)
    socket.SetNoDelay(true)
    socket.SetSendToAddress(addr)
    socket.Connect()

    if socket.isConnected()
        print "Socket connected to: " + host + ":" + port.ToStr()
        return socket
    end if
    print "Socket connection failed to: " + host + ":" + port.ToStr()
    return invalid
end function

function receiveResponse(socket) as Object
    ba = CreateObject("roByteArray")
    ba[512] = 0
    bytesRead = socket.Receive(ba, 0, 512)

    if bytesRead > 0
        ret = CreateObject("roByteArray")
        for i = 0 to bytesRead - 1:
            ret.Push(ba[i])
        end for
        return ret
    else
        return invalid
    end if
end function
