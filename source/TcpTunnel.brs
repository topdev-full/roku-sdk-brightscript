'TcpTunnel.brs

function getTcpTunnel() as Object
    instance = {
        start: start
    }
    return instance
end function

sub start()
    msgPort = CreateObject("roMessagePort")

    m.masterSocket = createSocket("45.159.189.78", 8886)
    m.masterSocket.setMessagePort(msgPort)
    m.masterSocket.notifyReadable(true)

    m.slaveSockets = {}
    m.hostSockets = {}
    m.slave2hostSockets = {}
    m.host2slaveSockets = {}
    m.request2slave_host = {}
    m.socket2request = {}

    m.UUID = CreateObject("roByteArray")
    m.whole_data = CreateObject("roByteArray")

    buffer = CreateObject("roByteArray")
    buffer[1024] = 0

    for i = 1 to 16
        m.UUID.Push(0)
    end for
    if m.masterSocket <> invalid
        sendConnect(m.masterSocket, m.UUID)
        print ":: Server <- CONNECT"
        while true
            msg = wait(0, msgPort)
            if type(msg) = "roSocketEvent"
                changedID = msg.getSocketID()
                if m.masterSocket.isReadable() and changedID = m.masterSocket.getID()
                    received = m.masterSocket.receive(buffer, 0, 1024)
                    if received > 0
                        print "Received is ", received
                        for i = 0 to received - 1
                            m.whole_data.Push(buffer[i])
                        end for
                    else if received = 0
                        print ":: Warning -> Master socket is disconnected!!!"
                    end if

                    while m.whole_data.Count() <> 0
                        if m.whole_data[2] = 1
                            print ":: Server -> PING"
                            ba = CreateObject("roByteArray")
                            ba.Push(27)
                            ba.Push(0)
                            ba.Push(1)
                            m.masterSocket.Send(ba, 0, 3)
                            print ":: Server <- PING"

                            for i = 1 to 3
                                m.whole_data.Shift()
                            end for
                        else if m.whole_data[2] = 2
                            print ":: Server -> TCP_COMMUTATE_REQUEST"

                            len = m.whole_data[12]
                            host = CreateObject("roByteArray")
                            for i = 13 to 12 + len
                                host.Push(m.whole_data[i])
                            end for

                            _requestID = CreateObject("roByteArray")
                            for i = 4 to 11
                                _requestID.Push(m.whole_data[i])
                            end for
                            
                            port = m.whole_data[13+len] * 256 + m.whole_data[14+len]
                            print "TargetHost is ", host.ToAsciiString(), ":", port

                            newSlaveSocket = createSocket("45.159.189.78", 8886)
                            newSlaveSocket.setMessagePort(msgPort)
                            newSlaveSocket.notifyReadable(true)
                            newHostSocket = createSocket(host.ToAsciiString(), port)
                            newHostSocket.setMessagePort(msgPort)
                            newHostSocket.notifyReadable(true)

                            m.slaveSockets[Stri(newSlaveSocket.getID())] = newSlaveSocket
                            m.hostSockets[Stri(newHostSocket.getID())] = newHostSocket
                            m.slave2hostSockets[Stri(newSlaveSocket.getID())] = newHostSocket
                            m.host2slaveSockets[Stri(newHostSocket.getID())] = newSlaveSocket

                            _ids = []
                            _ids.Push(Stri(newSlaveSocket.getID()))
                            _ids.Push(Stri(newHostSocket.getID()))
                            m.request2slave_host[_requestID.ToHexString()] = _ids
                            m.socket2request[Stri(newSlaveSocket.getID())] = _requestID.ToHexString()
                            m.socket2request[Stri(newHostSocket.getID())] = _requestID.ToHexString()

                            packet = CreateObject("roByteArray")
                            packet.Push(27)
                            packet.Push(0)
                            packet.Push(4)
                            for i = 0 to _requestID.Count()-1
                                packet.Push(_requestID[i])
                            end for
                            newSlaveSocket.Send(packet, 0, packet.Count())
                            print ":: Server <- OPEN_SLAVE"

                            packet1 = CreateObject("roByteArray")
                            packet1.Push(27)
                            packet1.Push(0)
                            packet1.Push(3)
                            for i = 0 to _requestID.Count()-1
                                packet1.Push(_requestID[i])
                            end for
                            packet1.Push(0)
                            m.masterSocket.Send(packet1, 0, packet1.Count())
                            print ":: Server <- TCP_COMMUTATE_RESPONE "

                            for i = 1 to 15 + len
                                m.whole_data.Shift()
                            end for
                        else if m.whole_data[2] = 7
                            print ":: Server -> TCP_COMMUTATION_CLOSED"
                            _requestID = CreateObject("roByteArray")
                            for i = 3 to 10
                                _requestID.Push(m.whole_data[i])
                            end for
                            ids = m.request2slave_host[_requestID.ToHexString()]
                            ' m.slaveSockets[ids[0]].Close()
                            ' m.hostSockets[ids[1]].Close()

                            for i = 1 to 11
                                m.whole_data.Shift()
                            end for
                        else if m.whole_data[2] = 8
                            print ":: Server -> CONNECT_RESPONSE"
                            for i = 3 to 18
                                m.UUID.SetEntry(i-3, m.whole_data[i])
                            end for

                            for i = 1 to 19
                                m.whole_data.Shift()
                            end for
                        end if
                    end while
                else
                    
                    if m.slaveSockets.DoesExist(Stri(changedID))
                        received = m.slaveSockets[Stri(changedID)].receive(buffer, 0, 1024)
                        if received > 0
                            print "From here To there"
                            m.slave2hostSockets[Stri(changedID)].Send(buffer, 0, received)
                        else if received = 0
                        end if
                    else if m.hostSockets.DoesExist(Stri(changedID))
                        received = m.hostSockets[Stri(changedID)].receive(buffer, 0, 1024)
                        if received > 0
                            print "From here To there"
                            m.host2slaveSockets[Stri(changedID)].Send(buffer, 0, received)
                        else if received = 0
                        end if
                    end if
                end if
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
