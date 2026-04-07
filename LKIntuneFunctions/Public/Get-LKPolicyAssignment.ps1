function Get-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Shows the assignment details (includes, excludes) for one or more policies.
    .EXAMPLE
        Get-LKPolicy -Name "XW365" | Get-LKPolicyAssignment
    .EXAMPLE
        Get-LKPolicyAssignment -PolicyId 'abc-123' -PolicyType SettingsCatalog
    .EXAMPLE
        Get-LKPolicy -Name "XW365" | Get-LKPolicyAssignment -DisplayAs Table
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$PolicyId,

        [Parameter(ParameterSetName = 'ById')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string]$PolicyType,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    begin {
        Assert-LKSession
        $groupNameCache = @{}
        if ($DisplayAs -eq 'Table') { $collector = [System.Collections.Generic.List[object]]::new() }
    }

    process {
        if ($InputObject) {
            $id   = $InputObject.Id
            $name = $InputObject.Name
            $type = $InputObject.PolicyType
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $type }
        } elseif ($PolicyType) {
            $id   = $PolicyId
            $name = $null
            $type = $PolicyType
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $PolicyType }
        } else {
            try {
                $resolved = Resolve-LKPolicyTypeById -PolicyId $PolicyId
                $id        = $PolicyId
                $name      = $resolved.PolicyName
                $type      = $resolved.TypeEntry.TypeName
                $typeEntry = $resolved.TypeEntry
            } catch {
                Write-Warning $_.Exception.Message
                return
            }
        }

        if (-not $typeEntry) {
            Write-Warning "Could not resolve policy type for '$id'."
            return
        }

        try {
            $assignments = Get-LKRawAssignment -PolicyId $id -PolicyType $typeEntry
        } catch {
            Write-Warning "Failed to get assignments for $id ($type): $($_.Exception.Message)"
            return
        }

        foreach ($assignment in $assignments) {
            $target = $assignment.target
            if (-not $target) { continue }

            $odataType = $target.'@odata.type'
            $groupId   = $target.groupId
            $groupName = $null

            $assignmentType = switch -Wildcard ($odataType) {
                '*exclusionGroupAssignmentTarget'   { 'Exclude'; break }
                '*groupAssignmentTarget'            { 'Include'; break }
                '*allDevicesAssignmentTarget'        { 'AllDevices'; break }
                '*allUsersAssignmentTarget'          { 'AllUsers'; break }
                '*allLicensedUsersAssignmentTarget'  { 'AllLicensedUsers'; break }
                default                              { 'Unknown' }
            }

            if ($groupId) {
                if ($groupNameCache.ContainsKey($groupId)) {
                    $groupName = $groupNameCache[$groupId]
                } else {
                    try {
                        $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$groupId`?`$select=displayName" -ApiVersion 'v1.0'
                        $groupName = if ($grp.displayName) { $grp.displayName } else { $groupId }
                    } catch {
                        $groupName = $groupId
                    }
                    $groupNameCache[$groupId] = $groupName
                }
            }

            # Capture assignment filter info if present
            $filterType = $target.deviceAndAppManagementAssignmentFilterType
            $filterId   = $target.deviceAndAppManagementAssignmentFilterId

            $obj = [PSCustomObject]@{
                PSTypeName     = 'LKPolicyAssignment'
                PolicyId       = $id
                PolicyName     = $name
                PolicyType     = $type
                AssignmentType = $assignmentType
                GroupId        = $groupId
                GroupName      = $groupName
                FilterType     = $filterType
                FilterId       = $filterId
                Intent         = $assignment.intent
            }
            if ($DisplayAs -eq 'Table') { $collector.Add($obj) } else { $obj }
        }
    }

    end {
        if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
            $collector | Format-Table AssignmentType, GroupName, Intent -AutoSize
        }
    }
}
