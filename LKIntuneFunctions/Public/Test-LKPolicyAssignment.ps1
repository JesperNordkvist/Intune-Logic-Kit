function Test-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Audits Intune policies for scope mismatches — device policies assigned to user groups (or vice versa).
    .DESCRIPTION
        Iterates all (or filtered) policy types, resolves each policy's effective scope,
        fetches assignments, determines each assigned group's scope via transitive membership,
        and flags mismatches for review.

        Group scope results are cached per session to avoid redundant Graph calls.
    .EXAMPLE
        Test-LKPolicyAssignment
        Audits all policy types and returns mismatch objects.
    .EXAMPLE
        Test-LKPolicyAssignment -PolicyType SettingsCatalog, CompliancePolicy
        Audits only Settings Catalog and Compliance policies.
    .EXAMPLE
        Test-LKPolicyAssignment -Detailed
        Shows a formatted, color-coded summary of all findings.
    .EXAMPLE
        Test-LKPolicyAssignment -Name "XW365" | Format-Table
        Filters to policies matching "XW365" and displays as a table.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$PolicyType,

        [string[]]$Name,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [switch]$Detailed,

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    Assert-LKSession

    $types = if ($PolicyType) {
        $script:LKPolicyTypes | Where-Object { $_.TypeName -in $PolicyType }
    } else {
        $script:LKPolicyTypes
    }

    # Caches to avoid repeated Graph calls
    $groupScopeCache = @{}     # GroupId -> @{ Scope; DeviceCount; UserCount }
    $groupNameCache = @{}      # GroupId -> DisplayName

    $issues = [System.Collections.Generic.List[object]]::new()

    $totalTypes = $types.Count
    $currentType = 0

    foreach ($type in $types) {
        $currentType++
        Write-Progress -Activity 'Auditing policy assignments' `
            -Status "$($type.DisplayName) ($currentType of $totalTypes)" `
            -PercentComplete (($currentType / $totalTypes) * 100)

        # Fetch all policies of this type
        try {
            $rawPolicies = Invoke-LKGraphRequest -Method GET -Uri $type.Endpoint -ApiVersion $type.ApiVersion -All
        } catch {
            Write-Warning "Failed to query $($type.DisplayName): $($_.Exception.Message)"
            continue
        }

        if (-not $rawPolicies) { continue }

        foreach ($raw in $rawPolicies) {
            $nameProp = $type.NameProperty
            $policyName = $raw.$nameProp
            if (-not $policyName) { continue }

            $displayType = if ($type.TypeName -eq 'App' -and $raw.'@odata.type') {
                Resolve-LKAppDisplayType -ODataType $raw.'@odata.type'
            } else {
                $type.DisplayName
            }

            # Name filter
            if ($Name -and -not (Test-LKNameMatch -Value $policyName -Name $Name -NameMatch $NameMatch)) {
                continue
            }

            # Resolve the policy's effective scope
            $policyScope = if ($type.TargetScope -ne 'Both') {
                $type.TargetScope
            } else {
                Resolve-LKPolicyScope -RawPolicy $raw -PolicyType $type
            }

            # Both-scoped policies can't have a mismatch — skip
            if ($policyScope -eq 'Both') { continue }

            # Fetch assignments
            try {
                $assignments = Get-LKRawAssignment -PolicyId $raw.id -PolicyType $type
            } catch {
                Write-Verbose "Failed to fetch assignments for '$policyName': $($_.Exception.Message)"
                continue
            }

            if (-not $assignments -or $assignments.Count -eq 0) { continue }

            foreach ($assignment in $assignments) {
                $target = $assignment.target
                if (-not $target) { continue }

                $targetType = $target.'@odata.type'
                $groupId = $target.groupId

                # Classify assignment type
                $assignmentType = if ($targetType -like '*exclusion*') { 'Exclude' } else { 'Include' }

                # Handle broad assignment targets
                # Skip broad target mismatch checks for EnrollmentConfiguration — default
                # policies (Limits, Hello, ESP) are assigned to "All users and all devices"
                # by design and cannot be changed
                if ($targetType -like '*allDevicesAssignmentTarget*') {
                    if ($policyScope -eq 'User' -and $type.TypeName -ne 'EnrollmentConfiguration') {
                        $issues.Add([PSCustomObject]@{
                            PSTypeName   = 'LKPolicyAssignmentIssue'
                            PolicyId     = $raw.id
                            PolicyName   = $policyName
                            PolicyType   = $displayType
                            PolicyTypeId = $type.TypeName
                            PolicyScope  = $policyScope
                            AssignmentType = 'AllDevices'
                            GroupName    = 'All Devices'
                            GroupScope   = 'Device'
                            DeviceCount  = $null
                            UserCount    = $null
                            Severity     = 'Mismatch'
                            Detail       = "User-scoped policy is assigned to All Devices"
                        })
                    }
                    continue
                }

                if ($targetType -like '*allUsersAssignmentTarget*' -or $targetType -like '*allLicensedUsersAssignmentTarget*') {
                    $broadLabel = if ($targetType -like '*allLicensedUsers*') { 'All Licensed Users' } else { 'All Users' }
                    if ($policyScope -eq 'Device' -and $type.TypeName -ne 'EnrollmentConfiguration') {
                        $issues.Add([PSCustomObject]@{
                            PSTypeName   = 'LKPolicyAssignmentIssue'
                            PolicyId     = $raw.id
                            PolicyName   = $policyName
                            PolicyType   = $displayType
                            PolicyTypeId = $type.TypeName
                            PolicyScope  = $policyScope
                            AssignmentType = if ($targetType -like '*allLicensedUsers*') { 'AllLicensedUsers' } else { 'AllUsers' }
                            GroupName    = $broadLabel
                            GroupScope   = 'User'
                            DeviceCount  = $null
                            UserCount    = $null
                            Severity     = 'Mismatch'
                            Detail       = "Device-scoped policy is assigned to $broadLabel"
                        })
                    }
                    continue
                }

                # Skip non-group targets (shouldn't happen, but be safe)
                if (-not $groupId) { continue }

                # Resolve group name (cached)
                if (-not $groupNameCache.ContainsKey($groupId)) {
                    try {
                        $grp = Invoke-LKGraphRequest -Method GET `
                            -Uri "/groups/$groupId`?`$select=displayName" -ApiVersion 'v1.0'
                        $groupNameCache[$groupId] = $grp.displayName
                    } catch {
                        $groupNameCache[$groupId] = $groupId
                    }
                }
                $groupName = $groupNameCache[$groupId]

                # Resolve group scope transitively (cached)
                if (-not $groupScopeCache.ContainsKey($groupId)) {
                    $groupScopeCache[$groupId] = Resolve-LKGroupScopeTransitive -GroupId $groupId
                }
                $gScope = $groupScopeCache[$groupId]

                # Determine mismatch
                $severity = $null
                $detail = $null

                if ($gScope.Scope -eq 'Unknown') {
                    $severity = 'Info'
                    $detail = "Group scope could not be determined (empty or unresolvable group)"
                }
                elseif ($policyScope -eq 'Device' -and $gScope.Scope -eq 'User') {
                    $severity = 'Mismatch'
                    $detail = "Device-scoped policy assigned to user group ($($gScope.UserCount) users, $($gScope.DeviceCount) devices)"
                }
                elseif ($policyScope -eq 'User' -and $gScope.Scope -eq 'Device') {
                    $severity = 'Mismatch'
                    $detail = "User-scoped policy assigned to device group ($($gScope.DeviceCount) devices, $($gScope.UserCount) users)"
                }
                elseif ($policyScope -eq 'Device' -and $gScope.Scope -eq 'Both') {
                    $severity = 'Warning'
                    $detail = "Device-scoped policy assigned to mixed group ($($gScope.DeviceCount) devices, $($gScope.UserCount) users)"
                }
                elseif ($policyScope -eq 'User' -and $gScope.Scope -eq 'Both') {
                    $severity = 'Warning'
                    $detail = "User-scoped policy assigned to mixed group ($($gScope.UserCount) users, $($gScope.DeviceCount) devices)"
                }

                if ($severity) {
                    $issues.Add([PSCustomObject]@{
                        PSTypeName   = 'LKPolicyAssignmentIssue'
                        PolicyId     = $raw.id
                        PolicyName   = $policyName
                        PolicyType   = $displayType
                        PolicyTypeId = $type.TypeName
                        PolicyScope  = $policyScope
                        AssignmentType = $assignmentType
                        GroupName    = $groupName
                        GroupScope   = $gScope.Scope
                        DeviceCount  = $gScope.DeviceCount
                        UserCount    = $gScope.UserCount
                        Severity     = $severity
                        Detail       = $detail
                    })
                }
            }
        }
    }

    Write-Progress -Activity 'Auditing policy assignments' -Completed

    if ($Detailed) {
        $separator = [string]([char]0x2500) * 70
        $thinLine  = [string]([char]0x2500) * 68

        $mismatches = @($issues | Where-Object { $_.Severity -eq 'Mismatch' })
        $warnings = @($issues | Where-Object { $_.Severity -eq 'Warning' })
        $infos = @($issues | Where-Object { $_.Severity -eq 'Info' })

        Write-Host ''
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host "  POLICY ASSIGNMENT AUDIT" -ForegroundColor Cyan
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host ''

        # Summary counts
        Write-Host "  Results:  " -ForegroundColor Gray -NoNewline
        Write-Host "$($mismatches.Count) mismatches" -ForegroundColor $(if ($mismatches.Count -eq 0) { 'Green' } else { 'Red' }) -NoNewline
        Write-Host "  |  " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($warnings.Count) warnings" -ForegroundColor $(if ($warnings.Count -eq 0) { 'Green' } else { 'Yellow' }) -NoNewline
        Write-Host "  |  " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($infos.Count) unresolved" -ForegroundColor $(if ($infos.Count -eq 0) { 'Green' } else { 'DarkGray' })
        Write-Host ''

        if ($mismatches.Count -gt 0) {
            Write-Host "  MISMATCHES" -ForegroundColor Red -NoNewline
            Write-Host "  Wrong scope - policy will not apply correctly" -ForegroundColor DarkGray
            Write-Host "  $thinLine" -ForegroundColor DarkGray

            foreach ($m in $mismatches) {
                Write-Host ''
                Write-Host "    $($m.PolicyName)" -ForegroundColor White
                Write-Host "    Type       " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($m.PolicyType)" -ForegroundColor Gray
                Write-Host "    Scope      " -ForegroundColor DarkGray -NoNewline
                $scopeColor = switch ($m.PolicyScope) { 'Device' { 'Cyan' }; 'User' { 'DarkYellow' }; default { 'White' } }
                Write-Host "$($m.PolicyScope)-scoped" -ForegroundColor $scopeColor -NoNewline
                Write-Host "  >  " -ForegroundColor DarkGray -NoNewline
                $gScopeColor = switch ($m.GroupScope) { 'Device' { 'Cyan' }; 'User' { 'DarkYellow' }; default { 'White' } }
                Write-Host "$($m.GroupScope) group" -ForegroundColor $gScopeColor
                Write-Host "    Group      " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($m.GroupName)" -ForegroundColor White -NoNewline
                if ($m.AssignmentType -eq 'Exclude') {
                    Write-Host " (Exclude)" -ForegroundColor Magenta
                } else {
                    Write-Host ''
                }
                Write-Host "    Detail     " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($m.Detail)" -ForegroundColor DarkGray
            }
            Write-Host ''
        }

        if ($warnings.Count -gt 0) {
            Write-Host "  WARNINGS" -ForegroundColor Yellow -NoNewline
            Write-Host "  Mixed-scope groups - may partially apply" -ForegroundColor DarkGray
            Write-Host "  $thinLine" -ForegroundColor DarkGray

            foreach ($w in $warnings) {
                Write-Host ''
                Write-Host "    $($w.PolicyName)" -ForegroundColor White
                Write-Host "    Type       " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($w.PolicyType)" -ForegroundColor Gray
                Write-Host "    Scope      " -ForegroundColor DarkGray -NoNewline
                $scopeColor = switch ($w.PolicyScope) { 'Device' { 'Cyan' }; 'User' { 'DarkYellow' }; default { 'White' } }
                Write-Host "$($w.PolicyScope)-scoped" -ForegroundColor $scopeColor
                Write-Host "    Group      " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($w.GroupName)" -ForegroundColor White -NoNewline
                Write-Host " ($($w.GroupScope) - $($w.DeviceCount) devices, $($w.UserCount) users)" -ForegroundColor DarkGray
                if ($w.AssignmentType -eq 'Exclude') {
                    Write-Host "    Assign     " -ForegroundColor DarkGray -NoNewline
                    Write-Host "Exclude" -ForegroundColor Magenta
                }
            }
            Write-Host ''
        }

        if ($infos.Count -gt 0) {
            Write-Host "  UNRESOLVED" -ForegroundColor DarkGray -NoNewline
            Write-Host "  Empty or unresolvable groups - review manually" -ForegroundColor DarkGray
            Write-Host "  $thinLine" -ForegroundColor DarkGray
            Write-Host ''

            $infoByGroup = $infos | Group-Object GroupName
            foreach ($g in $infoByGroup) {
                $policyList = ($g.Group | ForEach-Object { $_.PolicyName }) -join ', '
                Write-Host "    $($g.Name)" -ForegroundColor Gray -NoNewline
                Write-Host " - $($g.Count) policies" -ForegroundColor DarkGray
                Write-Host "      $policyList" -ForegroundColor DarkGray
            }
            Write-Host ''
        }

        if (($mismatches.Count + $warnings.Count + $infos.Count) -eq 0) {
            Write-Host "  All policy assignments have correct scope alignment." -ForegroundColor Green
            Write-Host ''
        }

        Write-Host $separator -ForegroundColor DarkGray
        Write-Host ''
    }

    # Always emit objects to the pipeline (even in -Detailed mode, for capture)
    if ($DisplayAs -eq 'Table') {
        $colorRules = @{
            PolicyName = { param($val, $row) 'White' }
            PolicyScope = @{
                'Device' = 'Cyan'
                'User'   = 'DarkYellow'
                'Both'   = 'White'
            }
            GroupName  = { param($val, $row) 'White' }
            GroupScope = @{
                'Device'  = 'Cyan'
                'User'    = 'DarkYellow'
                'Both'    = 'Yellow'
                'Unknown' = 'DarkGray'
            }
            Severity   = @{
                'Mismatch' = 'Red'
                'Warning'  = 'Yellow'
                'Info'     = 'DarkGray'
            }
        }
        Write-LKTable -Data $issues -Columns PolicyName, PolicyScope, GroupName, GroupScope, Severity -ColorRules $colorRules
    } else {
        $issues
    }
}
