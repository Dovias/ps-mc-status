clear
function Get-MCVariableInteger {
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

function Parse-MCVariableInteger {
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


function Create-MCHandshakePacketData {
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
    $data = Create-MCHandshakePacketData $address.ToString() $port
    $stream.Write($data, 0, $data.Count)

    # Write set state packet
    $stream.Write([byte[]]@(0x1, 0x0), 0, 2)
    $stream.Flush()

    # We dont need the first varint which specifies packet payload size
    $null = Parse-MCVariableInteger $stream
    $null = $stream.ReadByte()
    # Parse length varint variable, which specifies packet string length.
    $length = Parse-MCVariableInteger $stream

    $bytesRead = 0
    # use the retrieve length for the result buffer
    $result = [byte[]]::new($length)
    while ($bytesRead -lt $length) {
       $bytesRead += $stream.Read($result, $bytesRead, $length-$bytesRead)
    }
    
    return [System.Text.Encoding]::UTF8.GetString($result)
}

function Get-MCServerVersion {
    param([int16]$protocolId)

    $version = switch ($protocolId) {
        764 { "1.20.2" }
        763 { "1.20.1" }
        762 { "1.19.4" }
        761 { "1.19.3" }
        760 { "1.19.2" }
        759 { "1.19" }
        758 { "1.18.2" }
        757 { "1.18.1" }
        756 { "1.17.1" }
        755 { "1.17" }
        754 { "1.16.5" }
        753 { "1.16.3" }
        751 { "1.16.2" }
        736 { "1.16.1" }
        735 { "1.16" }
        578 { "1.15.2" }
        575 { "1.15.1" }
        573 { "1.15" }
        498 { "1.14.4" }
        490 { "1.14.3" }
        485 { "1.14.2" }
        480 { "1.14.1" }
        477 { "1.14" }
        404 { "1.13.2" }
        401 { "1.13.1" }
        393 { "1.13" }
        340 { "1.12.2" }
        338 { "1.12.1" }
        335 { "1.12" }
        316 { "1.11.2" }
        315 { "1.11" }
        210 { "1.10.2" }
        110 { "1.9.4" }
        109 { "1.9.2" }
        108 { "1.9.1" }
        107 { "1.9" }
        47 { "1.8.9" }
        5 { "1.7.10" }
        4 { "1.7.5" }
        default { "unknown" }
    }

    return $version

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
        "`nMinecraft server status checker"
        "https://github.com/Dovias/ps-mc-status/tree/main"

        Write-Host "`n SERVER CONNECTION DETAILS: " -BackgroundColor White -ForegroundColor Black
        " - Server hostname or ip: $($address)"
        " - Server port: $($port)"
    }

    Process {
        try {
            $status = ConvertFrom-Json (Get-MCServerStatusData $address $port)

        } catch [System.Net.Sockets.SocketException] {
            Write-Host "`n FAILED TO ESTABLISH CONNECTION WITH THE SERVER! `n" -BackgroundColor Red -ForegroundColor White
            return
        }
        $protocolId = $status.version.protocol
        $version = Get-MCServerVersion $protocolId

        Write-Host "`n SERVER IS ONLINE: " -BackgroundColor Green -ForegroundColor Black
        Write-Host " - Server online players: " -ForegroundColor White -NoNewline
        Write-Host "$($status.players.online)/$($status.players.max)" -ForegroundColor Green
        Write-Host " - Server version: " -ForegroundColor White -NoNewLine
        Write-Host "$($version) (protocol id: $($protocolId))" -ForegroundColor Green
        Write-Host " - Server software name: " -ForegroundColor White -NoNewLine
        Write-Host "'$($status.version.name)'" -ForegroundColor Green

        if (($version -eq "unknown") -or ($status.version.name -match "§")) {
            Write-Host "`n SERVER METADATA SEEMS TO BE MODIFIED!" -BackgroundColor Yellow -ForegroundColor Black
        }
        "`n"

    }
}