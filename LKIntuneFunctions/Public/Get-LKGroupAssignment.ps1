function Get-LKGroupAssignment {
    <#
    .SYNOPSIS
        Finds all Intune policies where a specific group is assigned (included or excluded).
    .DESCRIPTION
        Reverse lookup - iterates across all policy types and checks each policy's
        assignments for the specified group(s). Slow but comprehensive.

        When using -Name with the default NameMatch (Contains), multiple groups may match.
        All matching groups are scanned. Use -NameMatch Exact to restrict to a single group.

        Policies assigned to "All Devices" or "All Users" are also included when they
        would effectively target the group (based on the group's member scope), unless
        the group is explicitly excluded from that policy.

        Policy scope is automatically resolved via Graph metadata so that ScopeMismatch
        is accurate for all policy types. Use -SkipScopeResolution to disable this and
        fall back to the static registry scope (faster but ScopeMismatch will be $null
        for 'Both'-typed policies like SettingsCatalog).
    .EXAMPLE
        Get-LKGroupAssignment -Name 'SG-Windows-ExampleGroup'
    .EXAMPLE
        Get-LKGroupAssignment -Name 'XW365-Intune-D-Pilot Devices' -NameMatch Exact
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot' -NameMatch Contains -PolicyType CompliancePolicy
    .EXAMPLE
        Get-LKGroupAssignment -GroupId 'abc-123' -PolicyType CompliancePolicy, SettingsCatalog
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -NameMatch Exact
        Shows assignments with resolved policy scope and mismatch detection.
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' | Where-Object ScopeMismatch
        Shows only scope-mismatched assignments (e.g. device group on a user-scoped policy).
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -SkipScopeResolution
        Faster scan without dynamic scope resolution (ScopeMismatch will be $null for 'Both' types).
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType Exclude
        Shows only policies where the group is excluded.
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType All
        Shows both include and exclude assignments for the group.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$GroupId,

        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$PolicyType,

        [switch]$SkipScopeResolution,

        [ValidateSet('Include', 'Exclude', 'All')]
        [string]$AssignmentType = 'Include'
    )

    Assert-LKSession

    # Resolve target group(s)
    $targetGroups = @()

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        if ($NameMatch -eq 'Exact' -and $Name.Count -eq 1) {
            $resolvedId = Resolve-LKGroupId -GroupName $Name[0]
            $targetGroups += @{ Id = $resolvedId; Name = $Name[0] }
        } else {
            $allGroups = @(Get-LKGroup -Name $Name -NameMatch $NameMatch)
            if (-not $allGroups -or $allGroups.Count -eq 0) {
                Write-Warning "No groups found matching: $($Name -join ', ')"
                return
            }
            foreach ($g in $allGroups) {
                $targetGroups += @{ Id = $g.Id; Name = $g.Name }
            }
            if ($targetGroups.Count -gt 1) {
                Write-Host "  Found $($targetGroups.Count) matching groups:" -ForegroundColor Cyan
                foreach ($g in $targetGroups) {
                    Write-Host "    - $($g.Name)" -ForegroundColor White
                }
                Write-Host ''
            }
        }
    } else {
        $groupDisplayName = $GroupId
        try {
            $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$GroupId`?`$select=displayName" -ApiVersion 'v1.0'
            $groupDisplayName = $grp.displayName
        } catch {
            Write-Verbose "Could not resolve group display name for $GroupId`: $($_.Exception.Message)"
        }
        $targetGroups += @{ Id = $GroupId; Name = $groupDisplayName }
    }

    # Build a lookup hashtable for fast matching: groupId -> groupName
    $targetLookup = @{}
    foreach ($g in $targetGroups) {
        $targetLookup[$g.Id] = $g.Name
    }

    # Resolve group scopes to determine which broad targets apply
    $groupScopes = @{}
    foreach ($g in $targetGroups) {
        $groupScopes[$g.Id] = Resolve-LKGroupScope -GroupId $g.Id
    }

    $types = if ($PolicyType) {
        $script:LKPolicyTypes | Where-Object { $_.TypeName -in $PolicyType }
    } else {
        $script:LKPolicyTypes
    }

    $totalTypes = $types.Count
    $currentType = 0
    $groupLabel = if ($targetGroups.Count -eq 1) { $targetGroups[0].Name } else { "$($targetGroups.Count) groups" }

    foreach ($type in $types) {
        $currentType++
        Write-Progress -Activity "Scanning assignments for $groupLabel" -Status "$($type.DisplayName) ($currentType of $totalTypes)" -PercentComplete (($currentType / $totalTypes) * 100)

        try {
            $policies = Invoke-LKGraphRequest -Method GET -Uri $type.Endpoint -ApiVersion $type.ApiVersion -All
        } catch {
            Write-Warning "Failed to query $($type.DisplayName): $($_.Exception.Message)"
            continue
        }

        if (-not $policies) { continue }

        foreach ($policy in $policies) {
            $policyName = $policy.($type.NameProperty)
            $displayType = if ($type.TypeName -eq 'App' -and $policy.'@odata.type') {
                Resolve-LKAppDisplayType -ODataType $policy.'@odata.type'
            } else {
                $type.DisplayName
            }

            try {
                $assignments = Get-LKRawAssignment -PolicyId $policy.id -PolicyType $type
            } catch {
                continue
            }

            if (-not $assignments -or $assignments.Count -eq 0) { continue }

            # Collect explicit group matches and broad targets in one pass
            $explicitMatches   = @()
            $broadTargets      = @()
            $excludedGroupIds  = @()

            foreach ($assignment in $assignments) {
                $target = $assignment.target
                if (-not $target) { continue }

                $odataType = $target.'@odata.type'

                # Track exclusions so we can check them against broad targets
                if ($odataType -like '*exclusionGroupAssignmentTarget' -and $target.groupId) {
                    $excludedGroupIds += $target.groupId

                    if ($targetLookup.ContainsKey($target.groupId)) {
                        $explicitMatches += @{
                            AssignmentType = 'Exclude'
                            GroupId        = $target.groupId
                            GroupName      = $targetLookup[$target.groupId]
                        }
                    }
                    continue
                }

                # Explicit group include
                if ($target.groupId -and $targetLookup.ContainsKey($target.groupId)) {
                    $explicitMatches += @{
                        AssignmentType = 'Include'
                        GroupId        = $target.groupId
                        GroupName      = $targetLookup[$target.groupId]
                    }
                    continue
                }

                # Broad targets (All Devices, All Users, All Licensed Users)
                $broadType = switch -Wildcard ($odataType) {
                    '*allDevicesAssignmentTarget'       { 'AllDevices' }
                    '*allUsersAssignmentTarget'         { 'AllUsers' }
                    '*allLicensedUsersAssignmentTarget' { 'AllLicensedUsers' }
                    default                             { $null }
                }
                if ($broadType) {
                    $broadTargets += $broadType
                }
            }

            # Skip policies with no matches
            if ($explicitMatches.Count -eq 0 -and $broadTargets.Count -eq 0) { continue }

            # Resolve policy scope: free for static types, API call for 'Both' types
            $policyScope = if (-not $SkipScopeResolution -and $type.TargetScope -eq 'Both') {
                Resolve-LKPolicyScope -RawPolicy $policy -PolicyType $type
            } else {
                $type.TargetScope
            }

            # Emit explicit matches (filtered by -AssignmentType)
            foreach ($match in $explicitMatches) {
                if ($AssignmentType -ne 'All' -and $match.AssignmentType -ne $AssignmentType) { continue }

                $gScope = $groupScopes[$match.GroupId]
                $mismatch = if ($policyScope -in @('Device', 'User') -and $gScope -in @('Device', 'User')) {
                    $policyScope -ne $gScope
                } else { $null }

                [PSCustomObject]@{
                    PSTypeName     = 'LKGroupAssignment'
                    PolicyId       = $policy.id
                    PolicyName     = $policyName
                    PolicyType     = $type.TypeName
                    DisplayType    = $displayType
                    PolicyScope    = $policyScope
                    AssignmentType = $match.AssignmentType
                    GroupId        = $match.GroupId
                    GroupName      = $match.GroupName
                    GroupScope     = $gScope
                    ScopeMismatch  = $mismatch
                }
            }

            # Check broad targets: does "All Devices" / "All Users" implicitly cover any target group?
            # Broad targets are always include-type, so skip when filtering for Exclude only
            if ($broadTargets.Count -gt 0 -and $AssignmentType -ne 'Exclude') {
                foreach ($g in $targetGroups) {
                    $alreadyEmitted = $explicitMatches | Where-Object { $_.GroupId -eq $g.Id }
                    if ($alreadyEmitted) { continue }

                    if ($g.Id -in $excludedGroupIds) { continue }

                    $gScope = $groupScopes[$g.Id]

                    # Skip broad target matching when group scope is unknown — we can't
                    # confirm the group would be covered, so avoid false positives
                    if ($gScope -eq 'Unknown') { continue }

                    foreach ($broad in $broadTargets) {
                        $applies = switch ($broad) {
                            'AllDevices' {
                                $gScope -in @('Device', 'Both')
                            }
                            'AllUsers' {
                                $gScope -in @('User', 'Both')
                            }
                            'AllLicensedUsers' {
                                $gScope -in @('User', 'Both')
                            }
                        }

                        if ($applies) {
                            # For broad targets, check mismatch between policy scope and the broad target's implied scope
                            $broadImpliedScope = switch ($broad) {
                                'AllDevices'       { 'Device' }
                                'AllUsers'         { 'User' }
                                'AllLicensedUsers' { 'User' }
                            }
                            $mismatch = if ($policyScope -in @('Device', 'User') -and $broadImpliedScope) {
                                $policyScope -ne $broadImpliedScope
                            } else { $null }

                            [PSCustomObject]@{
                                PSTypeName     = 'LKGroupAssignment'
                                PolicyId       = $policy.id
                                PolicyName     = $policyName
                                PolicyType     = $type.TypeName
                                DisplayType    = $displayType
                                PolicyScope    = $policyScope
                                AssignmentType = $broad
                                GroupId        = $g.Id
                                GroupName      = $targetLookup[$g.Id]
                                GroupScope     = $gScope
                                ScopeMismatch  = $mismatch
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    Write-Progress -Activity "Scanning assignments for $groupLabel" -Completed
}
