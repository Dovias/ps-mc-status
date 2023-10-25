$logDateFormat = "yyyy/MM/dd HH:mm:ss"
$logFormat = "[{0}] [{1}]: {2}"
function Log-Information {
    param(
        [string]
        $message
    )
    $date = Get-Date -Format $logDateFormat
    $message = $logFormat -f $date, "INFORMATION", $message
    Write-Output $message

}

function Log-Success {
    param(
        [string]
        $message
    )
    $date = Get-Date -Format $logDateFormat
    $message = $logFormat -f $date, "SUCCESS", $message
    Write-Output $message

}

function Log-Warning {
    param(
        [string]
        $message
    )
    $date = Get-Date -Format $logDateFormat
    $message = $logFormat -f $date, "WARNING", $message
    Write-Output $message
}

function Log-Failure {
    param(
        [string]
        $message
    )
    $date = Get-Date -Format $logDateFormat
    $message = $logFormat -f $date, "FAILURE", $message
    Write-Output $message
}

# Unused function, but may be used in the future
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

<#
.SYNOPSIS
    Retrieves the minecraft server status data from the server.

.DESCRIPTION
    Allows to the retrieve all realtime information (version, online players, software name) about the specific minecraft server

.PARAMETER address
    Specifies the IP address or hostname of the Minecraft server.

.PARAMETER port
    Specifies the TCP port number of Minecraft server. 25565 is the default.

.PARAMETER raw
    Specifies whether the return value should be byte array data type.

.EXAMPLE
    PS>Get-MCServerStatusData -address mc.hypixel.net
#>
function Get-MCServerStatusData {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]
        $address,

        [Parameter()]
        [uint16]
        $port = 25565,

        [Parameter()]
        [switch]
        $raw
    )

    Process {
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
    
        if ($raw) {
            return $result
        }
        return ConvertFrom-Json ([System.Text.Encoding]::UTF8.GetString($result))
    }
}


<#
.SYNOPSIS
    Retrieves Minecraft server version

.DESCRIPTION
    Allows to retrieve Minecraft server version from Minecraft server state protocol id

.PARAMETER id
    Specifies the minecraft release version protocol id

.EXAMPLE
    PS>Get-MCServerVersion -id 47
#>
function Get-MCServerVersion {
    Param(
        [Parameter(Mandatory = $true)]
        [int16]
        $id
    )

    Process {
        $version = switch ($id) {
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
}

<#
.SYNOPSIS
    Checks the server status of the minecraft server

.DESCRIPTION
    Allows to the check the specific realtime information (version, online players, software name) about the specific minecraft server

.PARAMETER address
    Specifies the IP address or hostname of the Minecraft server.

.PARAMETER port
    Specifies the TCP port number of Minecraft server. 25565 is the default.

.EXAMPLE
    PS>Get-MCServerStatus -address mc.hypixel.net
#>
function Get-MCServerStatus {

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $address,

        # Minecraft server port number
        [Parameter()]
        [uint16]
        $port = 25565
    )

    Begin {
        "`nMinecraft server status checker"
        "https://github.com/Dovias/ps-mc-status/tree/main`n"
    }

    Process {
        Log-Information "Attempting to connect with these server details:"
        Log-Information "Server hostname or IP address: $($address)"
        Log-Information "Server port: $($port)"
        try {
            $status = Get-MCServerStatusData $address $port
        } catch [System.Net.Sockets.SocketException] {
            Log-Failure "Failed to establish connection with the server"
            return
        } catch {
            Log-Failure "Failed to communicate with the server. It might be running unsupported, old or newer version of minecraft server software"
            return
        }
        $protocolId = $status.version.protocol
        $version = Get-MCServerVersion $protocolId

        Log-Success "Successfully connected to the server: "
        Log-Success "Server online players: $($status.players.online)/$($status.players.max)"
        Log-Success "Server version: $($version) (protocol id: $($protocolId))"
        Log-Success "Server software name: '$($status.version.name)'"

        # Not the best detection, but its still better than nothing, since we can't really properly detect it
        if ($status.version.name -match "§") {
            Log-Warning "Server metadata seems to be modified. Some information about the server might be inaccurate!"
        }

    }
}