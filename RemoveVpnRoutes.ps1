#Requires -RunAsAdministrator

function RemoveVpnRoutes {
    param ($vpnName)

    # Get a list of AWS regions
    $vpnRoutes = (Get-VpnConnection -Name $vpnName).routes

    foreach ($route in $vpnRoutes) {
        "Removing IP range from VPN routes - {0}" -f $route.DestinationPrefix | Write-Output
        Remove-VpnConnectionRoute -ConnectionName $vpnName -DestinationPrefix $route.DestinationPrefix
    }

    "Please reconnect to the VPN to complete the removal" | Write-Output
}

$validVpnConnections = @(Get-VpnConnection | Select-Object -ExpandProperty Name)

$selectedVpnName = "";
$vpnCount = $validVpnConnections.Length;

if ($vpnCount -eq 0) {
    Write-Error "No VPN connection configured, nothing to do";
    exit 1
} 

if ($vpnCount -eq 1) 
{
    $selectedVpnName = $validVpnConnections[0]
    "I only found 1 connection with the name of {0}" -f $selectedVpnName | Write-Output
    $input = Read-Host "do you want to configure it? [Y/N]"

    if ($input.ToString().ToLower() -eq "y")
    {
        RemoveVpnRoutes($selectedVpnName);
    }
    else
    {
        "Not configuring any VPN connections, have a good day!" | Write-Output
    }
} 
else 
{
    "I found the following VPN connections" | Write-Output
    $i = 0;
    foreach ($connection in $validVpnConnections) {
        $i++;
        "{0}: {1}" -f $i, $connection | Write-Output
    }

    do 
    {
        try 
        {
            $numberValid = $true;
            [int]$vpnConnectionIndex = Read-Host "Please select the connection by it's number"
        }
        catch 
        {
            $numberValid = $false
            "Invalid VPN connection!" | Write-Output
        }
    } until ($vpnConnectionIndex -ge 1 -and $vpnConnectionIndex -lt $vpnCount+1 -and $numberValid)

    RemoveVpnRoutes($validVpnConnections[$vpnConnectionIndex-1])
}
