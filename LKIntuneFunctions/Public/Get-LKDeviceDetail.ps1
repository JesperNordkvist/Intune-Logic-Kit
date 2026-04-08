function Get-LKDeviceDetail {
    <#
    .SYNOPSIS
        Returns detailed information for a specific Intune managed device.
    .EXAMPLE
        Get-LKDeviceDetail -Name "YOURPC-001"
    .EXAMPLE
        Get-LKDevice -User "Jesper" | Get-LKDeviceDetail
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$DeviceId,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject
    )

    begin {
        Assert-LKSession
    }

    process {
        $id = switch ($PSCmdlet.ParameterSetName) {
            'ById'       { $DeviceId }
            'ByPipeline' { $InputObject.Id }
            'ByName'     {
                $escaped = $Name.Replace("'", "''")
                $found = Invoke-LKGraphRequest -Method GET -Uri "/deviceManagement/managedDevices?`$filter=deviceName eq '$escaped'&`$select=id" -ApiVersion 'v1.0' -All
                if (-not $found -or $found.Count -eq 0) {
                    Write-Warning "Device '$Name' not found."
                    return
                }
                if ($found.Count -gt 1) {
                    Write-Warning "Multiple devices found matching '$Name'. Showing first result."
                }
                $found[0].id
            }
        }

        if (-not $id) { return }

        try {
            $device = Invoke-LKGraphRequest -Method GET -Uri "/deviceManagement/managedDevices/$id" -ApiVersion 'v1.0'
        } catch {
            Write-Warning "Failed to get device details for $id`: $($_.Exception.Message)"
            return
        }

        # Resolve Entra Object ID from azureADDeviceId
        $entraObjectId = $null
        if ($device.azureADDeviceId) {
            $entraIdMap = Resolve-LKEntraObjectId -DeviceIds @($device.azureADDeviceId)
            $entraObjectId = $entraIdMap[$device.azureADDeviceId]
        }

        # Fetch compliance and configuration states
        $complianceStates = @()
        $configStates     = @()
        try {
            $complianceStates = Invoke-LKGraphRequest -Method GET -Uri "/deviceManagement/managedDevices/$id/deviceCompliancePolicyStates" -ApiVersion 'v1.0' -All
        } catch {
            Write-Verbose "Failed to fetch compliance policy states for device $id`: $($_.Exception.Message)"
        }
        try {
            $configStates = Invoke-LKGraphRequest -Method GET -Uri "/deviceManagement/managedDevices/$id/deviceConfigurationStates" -ApiVersion 'v1.0' -All
        } catch {
            Write-Verbose "Failed to fetch configuration states for device $id`: $($_.Exception.Message)"
        }

        [PSCustomObject]@{
            PSTypeName              = 'LKDeviceDetail'
            Id                      = $device.id
            DeviceName              = $device.deviceName
            UserDisplayName         = $device.userDisplayName
            UserPrincipalName       = $device.userPrincipalName
            OS                      = $device.operatingSystem
            OSVersion               = $device.osVersion
            ComplianceState         = $device.complianceState
            ManagementState         = $device.managementState
            EnrolledDateTime        = $device.enrolledDateTime
            LastSyncDateTime        = $device.lastSyncDateTime
            Model                   = $device.model
            Manufacturer            = $device.manufacturer
            SerialNumber            = $device.serialNumber
            AzureADDeviceId         = $device.azureADDeviceId
            EntraObjectId           = $entraObjectId
            EnrollmentType          = $device.deviceEnrollmentType
            JoinType                = $device.joinType
            Ownership               = $device.managedDeviceOwnerType
            TotalStorageGB          = [math]::Round($device.totalStorageSpaceInBytes / 1GB, 2)
            FreeStorageGB           = [math]::Round($device.freeStorageSpaceInBytes / 1GB, 2)
            EncryptionState         = $device.isEncrypted
            ComplianceGracePeriod   = $device.complianceGracePeriodExpirationDateTime
            PrimaryUser             = $device.userPrincipalName
            CompliancePolicyStates  = $complianceStates | ForEach-Object {
                [PSCustomObject]@{
                    PolicyName = $_.displayName
                    State      = $_.state
                }
            }
            ConfigurationStates     = $configStates | ForEach-Object {
                [PSCustomObject]@{
                    ProfileName = $_.displayName
                    State       = $_.state
                }
            }
        }
    }
}
