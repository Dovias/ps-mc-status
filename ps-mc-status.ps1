clear
function Get-VariableInteger {
    param([int]$integer)

    $dataMask = 0x7F
    $signMask = -bnot $dataMask

    [byte[]]$data = @()

    while ($true) {
        if (($integer -band $signMask) -eq 0) {
            $data += $integer
            break
        }

        [byte]$fragment = $integer -band $dataMask -bor 0x80
        $data += $fragment

        $integer = $integer -shr 7

    }
    return $data
}

function Parse-VariableInteger {
    param([System.IO.Stream]$stream)

    $dataMask = 0x7F
    $signMask = -bnot $dataMask

    $integer = 0;
    $index = 0;
    do {
        $data = $stream.ReadByte()

        $shiftAmount = $index * 7
        if ($data -band $signMask) {
            $integer = $integer -bor ([int]($data -band $dataMask) -shl $shiftAmount) 
        } else {
            $integer = $integer -bor ([int]$data -shl $shiftAmount)
            break
        }
        
        $index++
    } while ($true);

    return $integer
}


function Create-HandshakePacketData {
    param([string]$serverHostname, [uint16]$serverPort)

    # packet source: https://wiki.vg/Protocol#Handshake
    $data = [byte[]]::new($serverHostname.Length + 8)
    $data[0] = $data.Count - 1 # packet length
    $data[1] = 0 # packet type (handshake)
    $data[2] = 0xfc # protocol id varint most significant part
    $data[3] = 0x05 # protocol id varint least significant part
    $data[4] = $serverHostname.Length # server address name
    for ($index = 0; $index -lt $data[4]; $index++) {
        $data[5 + $index] = $serverHostname[$index]
    }
    $data[5 + $data[4]] = ($serverPort -band 0xFF00) -shr 8 # server port most significant part
    $data[6 + $data[4]] = $serverPort -band 0x00FF # server port least significant part
    $data[7 + $data[4]] = 0x01 # request type
    
    return $data
}

function Get-MCServerStatusData {
    param($address, [uint16]$port)

    $tcpClient = New-Object System.Net.Sockets.TCPClient($address, $port)

    $stream = $tcpClient.GetStream()

    # Write handshake packet
    $data = Create-HandshakePacketData $address.ToString() $port
    $stream.Write($data, 0, $data.Count)

    # Write set state packet
    $stream.Write([byte[]]@(0x1, 0x0), 0, 2)
    $stream.Flush()

    # We dont need the first varint which specifies packet payload size
    $null = Parse-VariableInteger $stream
    $null = $stream.ReadByte()
    # Parse length varint variable, which specifies packet string length.
    $length = Parse-VariableInteger $stream

    $bytesRead = 0
    # use the retrieve length for the result buffer
    $result = [byte[]]::new($length)
    while ($bytesRead -lt $length) {
       $bytesRead += $stream.Read($result, $bytesRead, $length-$bytesRead)
    }
    
    return [System.Text.Encoding]::UTF8.GetString($result)
}


function Get-MCServerStatus {

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $address,

        [Parameter()]
        [uint16]
        $port = 25565
    )

    Begin {
        "Minecraft server status"
        Write-Host "`nSERVER DETAILS" -BackgroundColor Gray -ForegroundColor White
        "Server hostname or ip: $($address)"
        "Server port: $($port)"
    }

    Process {
        $status = ConvertFrom-Json (Get-MCServerStatusData $address $port)

        Write-Host "`nSERVER IS ONLINE" -BackgroundColor Green -ForegroundColor White
        "Server online players: $($status.players.online)/$($status.players.max)"
        "Server protocol: $($status.version.protocol)"
        "Server name: $($status.version.name)"
    }
}