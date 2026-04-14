function Export-LKReportFromDirectEndpoint {
    <#
    .SYNOPSIS
        Fetches data from a direct Graph endpoint (no exportJobs) and writes it to CSV.
    .DESCRIPTION
        Internal helper used by Export-LKReport for report types that don't have an
        exportJobs report name — currently platform script run states.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ReportEntry,

        [Parameter(Mandatory)]
        [string]$PolicyId,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$Activity = 'Exporting Intune report'
    )

    $uri = $ReportEntry.Endpoint -f $PolicyId
    Write-Progress -Activity $Activity -Status 'Fetching run states...' -PercentComplete 20

    try {
        $items = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion $ReportEntry.ApiVersion -All
    } catch {
        Write-Progress -Activity $Activity -Completed
        throw "Failed to query '$uri': $($_.Exception.Message)"
    }

    Write-Progress -Activity $Activity -Status 'Flattening results...' -PercentComplete 60

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $items) {
        $row = [ordered]@{
            RunState                 = $item.runState
            ErrorCode                = $item.errorCode
            ErrorDescription         = $item.errorDescription
            LastStateUpdateDateTime  = $item.lastStateUpdateDateTime
            ResultMessage            = $item.resultMessage
            PreRemediationDetection  = $item.preRemediationDetectionScriptOutput
            PreRemediationError      = $item.preRemediationDetectionScriptError
            RemediationScriptError   = $item.remediationScriptError
            PostRemediationDetection = $item.postRemediationDetectionScriptOutput
        }

        if ($item.managedDevice) {
            $row['DeviceId']          = $item.managedDevice.id
            $row['DeviceName']        = $item.managedDevice.deviceName
            $row['UserPrincipalName'] = $item.managedDevice.userPrincipalName
            $row['UserDisplayName']   = $item.managedDevice.userDisplayName
            $row['OS']                = $item.managedDevice.operatingSystem
            $row['OSVersion']         = $item.managedDevice.osVersion
        }

        $rows.Add([PSCustomObject]$row)
    }

    Write-Progress -Activity $Activity -Status 'Writing CSV...' -PercentComplete 85

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    $destDir = Split-Path -Parent $resolvedPath
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if ($rows.Count -eq 0) {
        Set-Content -Path $resolvedPath -Value '# No run states found for this script.' -Encoding UTF8 -Force
    } else {
        $rows | Export-Csv -Path $resolvedPath -NoTypeInformation -Encoding UTF8 -Force
    }

    Write-Progress -Activity $Activity -Completed

    Get-Item -Path $resolvedPath
}
