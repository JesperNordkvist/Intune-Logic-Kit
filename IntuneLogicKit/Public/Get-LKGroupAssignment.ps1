function Get-LKGroupAssignment {
    <#
    .SYNOPSIS
        Finds all Intune policies where a specific group is assigned (included or excluded).
    .DESCRIPTION
        Reverse lookup - iterates across all policy types and checks each policy's
        assignments for the specified group(s). Comprehensive; app assignments are
        fetched in a single bulk call ($expand=assignments) so app-heavy tenants
        scan far faster. Combine with -PolicyType App -Platform to narrow further.

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
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -NameMatch Exact -PolicyType App -Platform Android
        Scans only Android apps for the group - much faster on app-heavy tenants,
        since non-Android apps are skipped before their assignments are fetched.
    .EXAMPLE
        Get-LKGroupAssignment -Name 'Pilot Devices' -DisplayAs Table
        Shows results as a compact table.
    .EXAMPLE
        Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users','SG-Intune-D-Pilot Devices' -NameMatch Exact -Effective
        Collapses assignments across the named groups into one row per policy, applying
        per-scope Exclude-wins. Returns EffectiveState + UserPath/DevicePath columns so
        you can see, for a user in the user group(s) + a device in the device group(s),
        which policies actually apply.
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
            'DriverUpdate', 'App', 'AutopilotDeploymentProfile'
        )]
        [string[]]$PolicyType,

        [ValidateSet('Android', 'iOS', 'macOS', 'Windows', 'Web')]
        [string[]]$Platform,

        [switch]$SkipScopeResolution,

        [ValidateSet('Include', 'Exclude', 'All')]
        [string]$AssignmentType = 'All',

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List',

        [switch]$Effective,

        [switch]$AppliedOnly
    )

    Assert-LKSession

    if ($Effective -and $AssignmentType -ne 'All') {
        Write-Warning "-Effective overrides -AssignmentType; computing across Include and Exclude together."
        $AssignmentType = 'All'
    }

    if ($AppliedOnly -and -not $Effective) {
        Write-Warning "-AppliedOnly requires -Effective; enabling -Effective."
        $Effective = $true
    }

    if ($DisplayAs -eq 'Table' -or $Effective) {
        $collector = [System.Collections.Generic.List[object]]::new()
    }

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

    if ($Platform -and -not ($types | Where-Object { $_.TypeName -eq 'App' })) {
        Write-Warning "-Platform only applies to the App policy type, which is not in scope; ignoring -Platform."
    }

    $totalTypes = $types.Count
    $currentType = 0
    $groupLabel = if ($targetGroups.Count -eq 1) { $targetGroups[0].Name } else { "$($targetGroups.Count) groups" }

    foreach ($type in $types) {
        $currentType++
        Write-Progress -Activity "Scanning assignments for $groupLabel" -Status "$($type.DisplayName) ($currentType of $totalTypes)" -PercentComplete (($currentType / $totalTypes) * 100)

        # Apps support bulk $expand=assignments - one paged call returns every app
        # with its assignments inline, avoiding a per-app assignment round-trip.
        # On app-heavy tenants that per-app fetch is the dominant cost (issue #15).
        $useExpand = $type.TypeName -eq 'App'
        $policyUri = if ($useExpand) { "$($type.Endpoint)?`$expand=assignments" } else { $type.Endpoint }

        try {
            $policies = Invoke-LKGraphRequest -Method GET -Uri $policyUri -ApiVersion $type.ApiVersion -All
        } catch {
            Write-Warning "Failed to query $($type.DisplayName): $($_.Exception.Message)"
            continue
        }

        if (-not $policies) { continue }

        foreach ($policy in $policies) {
            $policyName = $policy.($type.NameProperty)

            # Platform filter (App only) - applied early so non-matching apps skip
            # all downstream scope/filter resolution.
            if ($Platform -and $type.TypeName -eq 'App') {
                $appPlatform = if ($policy.'@odata.type') { Resolve-LKAppPlatform -ODataType $policy.'@odata.type' } else { $null }
                if ($appPlatform -notin $Platform) { continue }
            }

            $displayType = if ($type.TypeName -eq 'App' -and $policy.'@odata.type') {
                Resolve-LKAppDisplayType -ODataType $policy.'@odata.type'
            } else {
                $type.DisplayName
            }

            if ($useExpand) {
                # Assignments already came inline via $expand - no extra call.
                $assignments = @($policy.assignments)
            } else {
                try {
                    $assignments = Get-LKRawAssignment -PolicyId $policy.id -PolicyType $type
                } catch {
                    continue
                }
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
                            Intent         = $assignment.intent
                            FilterId       = $target.deviceAndAppManagementAssignmentFilterId
                            FilterType     = $target.deviceAndAppManagementAssignmentFilterType
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
                        Intent         = $assignment.intent
                        FilterId       = $target.deviceAndAppManagementAssignmentFilterId
                        FilterType     = $target.deviceAndAppManagementAssignmentFilterType
                    }
                    continue
                }

                # Broad targets (All Devices, All Users, All Licensed Users)
                $broadType = switch -Wildcard ($odataType) {
                    '*allDevicesAssignmentTarget'       { 'AllDevices'; break }
                    '*allUsersAssignmentTarget'         { 'AllUsers'; break }
                    '*allLicensedUsersAssignmentTarget' { 'AllLicensedUsers'; break }
                    default                             { $null }
                }
                if ($broadType) {
                    $broadTargets += @{ Type = $broadType; Intent = $assignment.intent }
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

            # Batch-resolve filter names for this policy's matches
            $filterIds = @($explicitMatches | ForEach-Object { $_.FilterId } | Where-Object { $_ })
            $filterNames = if ($filterIds.Count -gt 0) { Resolve-LKFilterName -FilterIds $filterIds } else { @{} }

            # Emit explicit matches (filtered by -AssignmentType)
            foreach ($match in $explicitMatches) {
                if ($AssignmentType -ne 'All' -and $match.AssignmentType -ne $AssignmentType) { continue }

                $gScope = $groupScopes[$match.GroupId]
                $mismatch = if ($policyScope -in @('Device', 'User') -and $gScope -in @('Device', 'User')) {
                    $policyScope -ne $gScope
                } else { $null }

                $obj = [PSCustomObject]@{
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
                    Intent         = $match.Intent
                    FilterId       = $match.FilterId
                    FilterName     = if ($match.FilterId) {
                        $fn = $filterNames[$match.FilterId]
                        $fm = if ($match.FilterType -eq 'include') { 'Include' } elseif ($match.FilterType -eq 'exclude') { 'Exclude' } else { $match.FilterType }
                        if ($fn) { "$fn ($fm)" } else { $fm }
                    } else { $null }
                    FilterType     = $match.FilterType
                }
                if ($null -ne $collector) { $collector.Add($obj) } else { $obj }
            }

            # Emit broad targets: show all AllDevices/AllUsers/AllLicensedUsers assignments
            # so the user sees the full picture of what hits this group.
            if ($broadTargets.Count -gt 0 -and $AssignmentType -ne 'Exclude') {
                foreach ($g in $targetGroups) {
                    # Skip if group already has an explicit match for this policy
                    $alreadyExplicit = $explicitMatches | Where-Object { $_.GroupId -eq $g.Id }
                    if ($alreadyExplicit) { continue }

                    # Skip if group is explicitly excluded from this policy
                    if ($g.Id -in $excludedGroupIds) { continue }

                    $gScope = $groupScopes[$g.Id]

                    foreach ($broad in $broadTargets) {
                        # When group scope is known, only show broad targets that apply
                        # When unknown, show all (can't determine which apply)
                        if ($gScope -notin @('Unknown', 'Both')) {
                            $applies = switch ($broad.Type) {
                                'AllDevices'       { $gScope -eq 'Device'; break }
                                'AllUsers'         { $gScope -eq 'User'; break }
                                'AllLicensedUsers' { $gScope -eq 'User'; break }
                            }
                            if (-not $applies) { continue }
                        }

                        $broadImpliedScope = switch ($broad.Type) {
                            'AllDevices'       { 'Device'; break }
                            'AllUsers'         { 'User'; break }
                            'AllLicensedUsers' { 'User'; break }
                        }
                        $mismatch = if ($policyScope -in @('Device', 'User') -and $broadImpliedScope) {
                            $policyScope -ne $broadImpliedScope
                        } else { $null }

                        $obj = [PSCustomObject]@{
                            PSTypeName     = 'LKGroupAssignment'
                            PolicyId       = $policy.id
                            PolicyName     = $policyName
                            PolicyType     = $type.TypeName
                            DisplayType    = $displayType
                            PolicyScope    = $policyScope
                            AssignmentType = $broad.Type
                            GroupId        = $g.Id
                            GroupName      = $targetLookup[$g.Id]
                            GroupScope     = $gScope
                            ScopeMismatch  = $mismatch
                            Intent         = $broad.Intent
                            FilterId       = $null
                            FilterName     = $null
                            FilterType     = $null
                        }
                        if ($null -ne $collector) { $collector.Add($obj) } else { $obj }
                        break  # One broad target match per group per policy is enough
                    }
                }
            }
        }
    }

    Write-Progress -Activity "Scanning assignments for $groupLabel" -Completed

    if ($Effective) {
        if (-not $collector -or $collector.Count -eq 0) { return }

        $effectiveResults = foreach ($group in ($collector | Group-Object PolicyId)) {
            $rows  = $group.Group
            $first = $rows[0]

            # Partition rows into user-scope / device-scope buckets.
            # Broad targets have inherent scope; Include/Exclude inherit group scope.
            # Unknown/Both group scope contributes to both buckets (conservative).
            $userRows   = [System.Collections.Generic.List[object]]::new()
            $deviceRows = [System.Collections.Generic.List[object]]::new()
            foreach ($r in $rows) {
                switch ($r.AssignmentType) {
                    'AllDevices'       { $deviceRows.Add($r); break }
                    'AllUsers'         { $userRows.Add($r);   break }
                    'AllLicensedUsers' { $userRows.Add($r);   break }
                    default {
                        switch ($r.GroupScope) {
                            'User'   { $userRows.Add($r) }
                            'Device' { $deviceRows.Add($r) }
                            default  { $userRows.Add($r); $deviceRows.Add($r) }
                        }
                    }
                }
            }

            $uInc = @($userRows   | Where-Object { $_.AssignmentType -in 'Include','AllUsers','AllLicensedUsers' })
            $uExc = @($userRows   | Where-Object { $_.AssignmentType -eq 'Exclude' })
            $dInc = @($deviceRows | Where-Object { $_.AssignmentType -in 'Include','AllDevices' })
            $dExc = @($deviceRows | Where-Object { $_.AssignmentType -eq 'Exclude' })

            # Per-scope exclude-wins: a user-group Exclude only cancels the
            # user-scope delivery path; a device-group Exclude only cancels
            # the device-scope path.
            $userDelivered   = $uInc.Count -gt 0 -and $uExc.Count -eq 0
            $deviceDelivered = $dInc.Count -gt 0 -and $dExc.Count -eq 0

            $deliveryRows      = @($uInc) + @($dInc) | Where-Object { $_ }
            $unfilteredDeliver = @($deliveryRows | Where-Object { -not $_.FilterName })

            $state = if ($userDelivered -or $deviceDelivered) {
                         if ($unfilteredDeliver.Count -gt 0) { 'Applied' } else { 'Conditional' }
                     }
                     elseif ($uExc.Count -gt 0 -or $dExc.Count -gt 0) { 'Excluded' }
                     else                                             { 'NotApplied' }

            $formatPath = {
                param($inc, $exc)
                if ($exc.Count -gt 0) {
                    'Excluded:' + (($exc | ForEach-Object GroupName | Select-Object -Unique) -join ',')
                } elseif ($inc.Count -gt 0) {
                    (@($inc | ForEach-Object {
                        if ($_.AssignmentType -eq 'Include') { "Include:$($_.GroupName)" } else { $_.AssignmentType }
                    } | Select-Object -Unique) -join '; ')
                } else { '-' }
            }

            $filters = @($rows | Where-Object FilterName | Select-Object -ExpandProperty FilterName -Unique)

            [PSCustomObject]@{
                PSTypeName     = 'LKEffectiveAssignment'
                PolicyId       = $first.PolicyId
                PolicyName     = $first.PolicyName
                PolicyType     = $first.PolicyType
                DisplayType    = $first.DisplayType
                PolicyScope    = $first.PolicyScope
                EffectiveState = $state
                UserPath       = & $formatPath $uInc $uExc
                DevicePath     = & $formatPath $dInc $dExc
                FilterName     = $filters -join '; '
            }
        }

        if ($AppliedOnly) {
            $effectiveResults = @($effectiveResults | Where-Object { $_.EffectiveState -in 'Applied','Conditional' })
        }

        if ($DisplayAs -eq 'Table') {
            $colorRules = @{
                PolicyName     = { param($val, $row) 'White' }
                DisplayType    = { param($val, $row) 'Gray' }
                EffectiveState = @{
                    'Applied'     = 'Green'
                    'Conditional' = 'DarkYellow'
                    'Excluded'    = 'Magenta'
                    'NotApplied'  = 'DarkGray'
                }
                PolicyScope    = @{
                    'Device' = 'Cyan'
                    'User'   = 'DarkYellow'
                    'Both'   = 'White'
                }
                FilterName     = { param($val, $row) if ($val) { 'DarkCyan' } else { 'DarkGray' } }
            }
            $columns = @('PolicyName', 'DisplayType', 'EffectiveState', 'UserPath', 'DevicePath')
            if ($effectiveResults | Where-Object { $_.FilterName }) { $columns += 'FilterName' }
            $columns += 'PolicyScope'
            Write-LKTable -Data $effectiveResults -Columns $columns -ColorRules $colorRules
        } else {
            $effectiveResults
        }
        return
    }

    if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
        $colorRules = @{
            PolicyName     = { param($val, $row) 'White' }
            DisplayType    = { param($val, $row) 'Gray' }
            AssignmentType = @{
                'Include'          = 'Green'
                'Exclude'          = 'Magenta'
                'AllDevices'       = 'DarkYellow'
                'AllUsers'         = 'DarkYellow'
                'AllLicensedUsers' = 'DarkYellow'
            }
            PolicyScope    = @{
                'Device' = 'Cyan'
                'User'   = 'DarkYellow'
                'Both'   = 'White'
            }
            Intent         = @{
                'required'  = 'Green'
                'available' = 'DarkYellow'
                'uninstall' = 'Magenta'
            }
            FilterName     = { param($val, $row) if ($val) { 'DarkCyan' } else { 'DarkGray' } }
        }
        $columns = @('PolicyName', 'DisplayType', 'AssignmentType')
        if ($collector | Where-Object { $_.FilterName }) { $columns += 'FilterName' }
        $columns += 'PolicyScope', 'Intent'
        Write-LKTable -Data $collector -Columns $columns -ColorRules $colorRules
    }
}
