function Get-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Shows the assignment details (includes, excludes) for one or more policies.
    .EXAMPLE
        Get-LKPolicy -Name "XW365" | Get-LKPolicyAssignment
    .EXAMPLE
        Get-LKPolicyAssignment -PolicyId 'abc-123' -PolicyType SettingsCatalog
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$PolicyId,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string]$PolicyType,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject
    )

    begin {
        Assert-LKSession
        $groupNameCache = @{}
    }

    process {
        if ($InputObject) {
            $id   = $InputObject.Id
            $type = $InputObject.PolicyType
            $name = $InputObject.Name
        } else {
            $id   = $PolicyId
            $type = $PolicyType
            $name = $null
        }

        $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $type }
        if (-not $typeEntry) {
            Write-Warning "Unknown policy type: $type"
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
                '*exclusionGroupAssignmentTarget' { 'Exclude' }
                '*groupAssignmentTarget'          { 'Include' }
                '*allDevicesAssignmentTarget'      { 'AllDevices' }
                '*allUsersAssignmentTarget'        { 'AllUsers' }
                '*allLicensedUsersAssignmentTarget' { 'AllLicensedUsers' }
                default                            { 'Unknown' }
            }

            if ($groupId) {
                if ($groupNameCache.ContainsKey($groupId)) {
                    $groupName = $groupNameCache[$groupId]
                } else {
                    try {
                        $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$groupId`?`$select=displayName" -ApiVersion 'v1.0'
                        $groupName = $grp.displayName
                    } catch {
                        $groupName = $groupId
                    }
                    $groupNameCache[$groupId] = $groupName
                }
            }

            [PSCustomObject]@{
                PSTypeName     = 'LKPolicyAssignment'
                PolicyId       = $id
                PolicyName     = $name
                PolicyType     = $type
                AssignmentType = $assignmentType
                GroupId        = $groupId
                GroupName      = $groupName
                Intent         = $assignment.intent
            }
        }
    }
}
