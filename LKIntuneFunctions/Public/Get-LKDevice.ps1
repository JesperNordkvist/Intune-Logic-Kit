function Get-LKDevice {
    <#
    .SYNOPSIS
        Queries Intune managed devices with flexible filtering.
    .EXAMPLE
        Get-LKDevice -Name "YOURPC" -NameMatch Contains
    .EXAMPLE
        Get-LKDevice -User "Jesper Nordkvist" -NameMatch Contains
    .EXAMPLE
        Get-LKDevice -User "Jesper" -NameMatch Contains -OS Windows
    .EXAMPLE
        Get-LKDevice -User "Jesper" -DisplayAs Table
    #>
    [CmdletBinding()]
    param(
        [string[]]$Name,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [string[]]$User,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$UserMatch = 'Contains',

        [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
        [string]$OS,

        [scriptblock]$FilterScript,

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    Assert-LKSession

    if ($DisplayAs -eq 'Table') { $collector = [System.Collections.Generic.List[object]]::new() }

    $selectFields = 'id,deviceName,userDisplayName,userPrincipalName,operatingSystem,osVersion,' +
                    'complianceState,managementState,enrolledDateTime,lastSyncDateTime,' +
                    'model,manufacturer,serialNumber,azureADDeviceId'

    # Build server-side filter where possible
    $filters = @()

    if ($Name -and $Name.Count -eq 1 -and $NameMatch -eq 'Exact') {
        $escaped = $Name[0].Replace("'", "''")
        $filters += "deviceName eq '$escaped'"
    }

    if ($OS) {
        $osMap = @{
            'Windows' = 'Windows'
            'iOS'     = 'iOS'
            'Android' = 'Android'
            'macOS'   = 'macOS'
        }
        $filters += "operatingSystem eq '$($osMap[$OS])'"
    }

    $uri = "/deviceManagement/managedDevices?`$select=$selectFields"
    if ($filters.Count -gt 0) {
        $filterString = $filters -join ' and '
        $uri += "&`$filter=$filterString"
    }

    $clientSideNameFilter = $Name -and ($NameMatch -ne 'Exact' -or $Name.Count -gt 1)
    $clientSideUserFilter = [bool]$User

    try {
        $devices = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -All
    } catch {
        throw "Failed to query devices: $($_.Exception.Message)"
    }

    if (-not $devices) { return }

    foreach ($device in $devices) {
        if ($clientSideNameFilter -and -not (Test-LKNameMatch -Value $device.deviceName -Name $Name -NameMatch $NameMatch)) {
            continue
        }

        if ($clientSideUserFilter) {
            $userMatched = (Test-LKNameMatch -Value $device.userDisplayName -Name $User -NameMatch $UserMatch) -or
                           (Test-LKNameMatch -Value $device.userPrincipalName -Name $User -NameMatch $UserMatch)
            if (-not $userMatched) { continue }
        }

        $obj = [PSCustomObject]@{
            PSTypeName       = 'LKDevice'
            Id               = $device.id
            DeviceName       = $device.deviceName
            UserDisplayName  = $device.userDisplayName
            UserPrincipalName = $device.userPrincipalName
            OS               = $device.operatingSystem
            OSVersion        = $device.osVersion
            ComplianceState  = $device.complianceState
            ManagementState  = $device.managementState
            EnrolledDateTime = $device.enrolledDateTime
            LastSyncDateTime = $device.lastSyncDateTime
            Model            = $device.model
            Manufacturer     = $device.manufacturer
            SerialNumber     = $device.serialNumber
            AzureADDeviceId  = $device.azureADDeviceId
        }

        if ($FilterScript -and -not ($obj | Where-Object $FilterScript)) {
            continue
        }

        if ($DisplayAs -eq 'Table') { $collector.Add($obj) } else { $obj }
    }

    if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
        $collector | Format-Table DeviceName, UserDisplayName, OS, ComplianceState, LastSyncDateTime -AutoSize
    }
}
