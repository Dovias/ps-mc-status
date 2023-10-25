# ps-mc-status
ps-mc-status is a PowerShell script, allowing to check the server state of the modern versions of Minecraft servers (Starting from version 1.7)

## Usage 📝
Before you start, you need to make sure that you have the PowerShell version ``5.1`` or later installed on machine. If the machine uses Windows 10, PowerShell ``5.1`` should be preinstalled already with the system.<br>

This script provides several functions that allow you to retrieve the data from the Minecraft server:<br><br>
``Get-MCServerStatus -address <address> -port <port number>`` command allows to retrieve the basic server information about the current server state (server software name, version and players)<br>
``Get-MCServerStatusData -address <address> [-port <port number>] [-raw]`` command allows to retrieve the PowerShell server information object about the current server state (server response data)<br>
``Get-MCServerIcon -path <icon output path> -address <address> [-port <port number>]`` command allows to retrieve the current server icon from the server and save it as a file on a computer

## Known issues 🦺
This implementation does not support DNS SRV record port number fetching. Some Minecraft servers use SRV records that allows them to dynamically provide the port number for the client without any explicit input from the client. Unfortunately, due to how .NET framework works, there's no way to parse the DNS SRV records data, since as of now, .NET only provides some methods for retrieval of IP addresses only. This means that some Minecraft servers from this script may show that they are offline, while in reality they are not. In this case, stating explicitly IP and port number of the server would solve this issue.
