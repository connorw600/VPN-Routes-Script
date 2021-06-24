#Requires -RunAsAdministrator

$vpnRouteInfo = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -ErrorAction SilentlyContinue
if ($vpnRouteInfo) {
    Write-Error "Please make sure the VPN is not configured to be your default gateway"
    exit 1
}

function ConfirmUserInput {
    param ($Prompt, $Yes, $No)

    $userInput = Read-Host -Prompt "$prompt [$yes/$no]"

    return $userInput.ToString().ToLower() -eq $yes.ToLower()
}

function AddVpnRoute {
    param ($VpnName, $IpRange) 
    
    Add-VpnConnectionRoute -ConnectionName $VpnName -DestinationPrefix $IpRange
    # "Adding IP range to {0} - {1}" -f $VpnName, $IpRange | Write-Output
}

function AddVpnRoutes {
    param ($vpnName)

    $additionalFileExists = Test-Path -Path "additional-ranges.txt";
    if ($additionalFileExists -eq $true) {
        "Reading additional IP route list" | Write-Output
        $additionalRanges = Get-Content -path "additional-ranges.txt"

        foreach ($additionalRange in $additionalRanges) {
            if ($additionalRange -ne "") {
                AddVpnRoute -VpnName $vpnName -IpRange $additionalRange
            }
        }
        "Additional IP routes added" | Write-Output
    }

    $ipRanges = $null

    $ipRangesFileExists = Test-Path -Path "ip-ranges.txt"
    if ($ipRangesFileExists -eq $true) {
        "Reading IP route list" | Write-Output
        $ipRange = Get-Content "ip-ranges.txt"
    } else {
        "Downloading Amazon AWS IP route list" | Write-Output
        # Get the list of eu-west-1 and eu-west-2 IP ranges
        $ipRanges = (Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/connorw600/Condensed-AWS-IP-ranges/ip-ranges/ip-ranges.txt").Content.Split("`n")
    }

    foreach ($ipRange in $ipRanges) {
        if ($ipRange -ne "") {
            AddVpnRoute -VpnName $vpnName -IpRange $ipRange
        }
    }
    "IP routes added" | Write-Output
    
    "Please reconnect to the VPN to complete the configuration process" | Write-Output
}


$validVpnConnections = @(Get-VpnConnection | Select-Object -ExpandProperty Name)

$selectedVpnName = ""
$vpnCount = $validVpnConnections.Length

if ($vpnCount -eq 0) {
    Write-Error "Please setup a VPN connection first"
    exit 1
} 

if ($vpnCount -eq 1) {
    $selectedVpnName = $validVpnConnections[0]
    "I only found 1 connection with the name of {0}" -f $selectedVpnName | Write-Output
    $modifyConfirmed = ConfirmUserInput -Prompt "Do you want to configure it" -Yes "Y" -No "N"

    if ($modifyConfirmed) {
        $vpnRoutes = (Get-VpnConnection -Name $selectedVpnName).routes

        if ($vpnRoutes.Length -gt 0) {
            "You have already configured routes, I will need to remove all of these routes before I can add the new routes" | Write-Output

            $confirmRemove = ConfirmUserInput -Prompt "Do you want to continue" -Yes "Y" -No "N"

            if ($confirmRemove) {
                "Removing old routes" | Write-Output
                foreach ($route in $vpnRoutes) {
                    #"Removing IP range from VPN routes - {0}" -f $route.DestinationPrefix | Write-Output
                    Remove-VpnConnectionRoute -ConnectionName $selectedVpnName -DestinationPrefix $route.DestinationPrefix
                }
            }
            else {
                "Not configuring any VPN connections, have a good day!" | Write-Output 
                exit 1
            }
        }

        AddVpnRoutes($selectedVpnName)
    }
    else {
        "Not configuring any VPN connections, have a good day!" | Write-Output 
    }
} 
else {
    "I found the following VPN connections" | Write-Output
    $i = 0
    foreach ($connection in $validVpnConnections) {
        "{0}: {1}" -f $i++, $connection | Write-Output
    }

    do {
        try {
            $numberValid = $true
            [int]$vpnConnectionIndex = Read-Host "Please select the connection by it's number"
        }
        catch {
            $numberValid = $false
            "Invalid VPN connection!" | Write-Output
        }
    } until ($vpnConnectionIndex -ge 1 -and $vpnConnectionIndex -lt $vpnCount + 1 -and $numberValid)

    AddVpnRoutes($validVpnConnections[$vpnConnectionIndex - 1])
}
