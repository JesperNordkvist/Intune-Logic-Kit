function Invoke-LKDeviceAction {
    <#
    .SYNOPSIS
        Triggers a remote action on an Intune managed device.
    .EXAMPLE
        Invoke-LKDeviceAction -DeviceName 'YOURPC-001' -Action Sync
    .EXAMPLE
        Get-LKDevice -User "Jesper" | Invoke-LKDeviceAction -Action Restart
    .EXAMPLE
        Invoke-LKDeviceAction -DeviceName 'YOURPC-001' -Action Wipe -KeepUserData
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Sync', 'Restart', 'RemoteLock', 'Retire', 'Wipe')]
        [string]$Action,

        [Parameter(Mandatory, ParameterSetName = 'ByDeviceName')]
        [string]$DeviceName,

        [Parameter(Mandatory, ParameterSetName = 'ByDeviceId')]
        [string]$DeviceId,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [switch]$KeepUserData,

        [switch]$KeepEnrollmentData
    )

    begin {
        Assert-LKSession -RequireWrite

        $actionMap = @{
            'Sync'       = 'syncDevice'
            'Restart'    = 'rebootNow'
            'RemoteLock' = 'remoteLock'
            'Retire'     = 'retire'
            'Wipe'       = 'wipe'
        }
        $actionEndpoint = $actionMap[$Action]
    }

    process {
        $managedDeviceId   = $null
        $deviceDisplayName = $null

        if ($InputObject) {
            $managedDeviceId   = $InputObject.Id
            $deviceDisplayName = $InputObject.DeviceName
        } elseif ($DeviceId) {
            $managedDeviceId   = $DeviceId
            $deviceDisplayName = $DeviceId
        } elseif ($DeviceName) {
            $escaped = $DeviceName.Replace("'", "''")
            $found = Invoke-LKGraphRequest -Method GET `
                -Uri "/deviceManagement/managedDevices?`$filter=deviceName eq '$escaped'&`$select=id,deviceName" `
                -ApiVersion 'v1.0' -All
            if (-not $found -or $found.Count -eq 0) {
                Write-Warning "Device '$DeviceName' not found."
                return
            }
            $managedDeviceId   = $found[0].id
            $deviceDisplayName = $found[0].deviceName
        }

        if (-not $managedDeviceId) {
            Write-Warning 'Could not determine managed device ID.'
            return
        }

        if ($Action -in @('Wipe', 'Retire')) {
            Write-Warning "The '$Action' action is destructive and cannot be undone."
        }

        Write-LKActionSummary -Action 'DEVICE ACTION' -Details ([ordered]@{
            Device = $deviceDisplayName
            Action = $Action
        })

        if ($PSCmdlet.ShouldProcess($deviceDisplayName, "$Action device")) {
            $uri = "/deviceManagement/managedDevices/$managedDeviceId/$actionEndpoint"
            $body = $null

            if ($Action -eq 'Wipe') {
                $body = @{
                    keepUserData       = [bool]$KeepUserData
                    keepEnrollmentData = [bool]$KeepEnrollmentData
                }
            }

            try {
                if ($body) {
                    Invoke-LKGraphRequest -Method POST -Uri $uri -ApiVersion 'v1.0' -Body $body | Out-Null
                } else {
                    Invoke-LKGraphRequest -Method POST -Uri $uri -ApiVersion 'v1.0' | Out-Null
                }
                [PSCustomObject]@{
                    DeviceName = $deviceDisplayName
                    DeviceId   = $managedDeviceId
                    Action     = $Action
                    Status     = 'Initiated'
                }
            } catch {
                Write-Warning "Failed to execute '$Action' on '$deviceDisplayName': $($_.Exception.Message)"
            }
        }
    }
}
