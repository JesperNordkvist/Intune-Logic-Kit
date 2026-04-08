function Test-LKPolicyConflict {
    <#
    .SYNOPSIS
        Detects policies with overlapping settings assigned to the same groups.
    .DESCRIPTION
        Scans policies, fetches their settings and assignments, then identifies cases
        where multiple policies configure the same setting and are assigned to at least
        one common group. These are potential conflicts where the winning policy depends
        on Intune's internal precedence rules.
    .EXAMPLE
        Test-LKPolicyConflict
        Scans all policy types for conflicts.
    .EXAMPLE
        Test-LKPolicyConflict -PolicyType SettingsCatalog, DeviceConfiguration
        Scans only specific policy types.
    .EXAMPLE
        Test-LKPolicyConflict -Setting "Firewall" -Detailed
        Searches for conflicts involving firewall-related settings and shows full details.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App', 'AutopilotDeploymentProfile'
        )]
        [string[]]$PolicyType,

        [string[]]$Setting,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$SettingMatch = 'Contains',

        [switch]$Detailed
    )

    Assert-LKSession

    $types = if ($PolicyType) {
        $script:LKPolicyTypes | Where-Object { $_.TypeName -in $PolicyType }
    } else {
        $script:LKPolicyTypes
    }

    # Phase 1: Collect settings and assignments for all policies
    $policyInfo = [System.Collections.Generic.List[object]]::new()
    $totalTypes = $types.Count
    $currentType = 0

    foreach ($type in $types) {
        $currentType++
        Write-Progress -Activity 'Scanning for policy conflicts' `
            -Status "Fetching $($type.DisplayName) ($currentType of $totalTypes)" `
            -PercentComplete (($currentType / $totalTypes) * 100)

        try {
            $rawPolicies = Invoke-LKGraphRequest -Method GET -Uri $type.Endpoint -ApiVersion $type.ApiVersion -All
        } catch {
            Write-Warning "Failed to query $($type.DisplayName): $($_.Exception.Message)"
            continue
        }

        if (-not $rawPolicies) { continue }

        foreach ($raw in $rawPolicies) {
            $nameProp = $type.NameProperty
            $pName = $raw.$nameProp
            if (-not $pName) { continue }

            # Fetch settings
            $settings = @()
            try {
                $settings = Get-LKPolicySettings -PolicyId $raw.id -PolicyType $type -RawPolicy $raw
            } catch { }

            if (-not $settings -or $settings.Count -eq 0) { continue }

            # Filter by setting name if specified
            if ($Setting) {
                $settings = @($settings | Where-Object {
                    Test-LKNameMatch -Value $_.Name -Name $Setting -NameMatch $SettingMatch
                })
                if ($settings.Count -eq 0) { continue }
            }

            # Fetch assignments
            $groupIds = @()
            try {
                $assignments = Get-LKRawAssignment -PolicyId $raw.id -PolicyType $type
                foreach ($a in $assignments) {
                    $target = $a.target
                    if ($target.groupId) {
                        $groupIds += $target.groupId
                    } elseif ($target.'@odata.type' -like '*allDevices*') {
                        $groupIds += 'AllDevices'
                    } elseif ($target.'@odata.type' -like '*allUsers*' -or $target.'@odata.type' -like '*allLicensedUsers*') {
                        $groupIds += 'AllUsers'
                    }
                }
            } catch { }

            if ($groupIds.Count -eq 0) { continue }

            $policyInfo.Add(@{
                Name       = $pName
                Id         = $raw.id
                Type       = $type.TypeName
                Settings   = $settings
                GroupIds   = $groupIds
            })
        }
    }

    Write-Progress -Activity 'Scanning for policy conflicts' -Status 'Analyzing...' -PercentComplete 90

    # Phase 2: Find conflicts — settings shared across policies with overlapping assignments
    # Index: setting name -> list of policies that configure it
    $settingIndex = @{}
    foreach ($p in $policyInfo) {
        foreach ($s in $p.Settings) {
            if (-not $settingIndex.ContainsKey($s.Name)) {
                $settingIndex[$s.Name] = [System.Collections.Generic.List[object]]::new()
            }
            $settingIndex[$s.Name].Add(@{
                PolicyName = $p.Name
                PolicyId   = $p.Id
                PolicyType = $p.Type
                Value      = $s.Value
                GroupIds   = $p.GroupIds
            })
        }
    }

    $conflicts = [System.Collections.Generic.List[object]]::new()

    foreach ($settingName in $settingIndex.Keys) {
        $entries = $settingIndex[$settingName]
        if ($entries.Count -lt 2) { continue }

        # Check each pair for overlapping group assignments
        for ($i = 0; $i -lt $entries.Count; $i++) {
            for ($j = $i + 1; $j -lt $entries.Count; $j++) {
                $a = $entries[$i]
                $b = $entries[$j]

                # Find common groups
                $commonGroups = @($a.GroupIds | Where-Object { $_ -in $b.GroupIds })
                if ($commonGroups.Count -eq 0) { continue }

                $valA = if ($null -eq $a.Value) { '(not set)' } else { "$($a.Value)" }
                $valB = if ($null -eq $b.Value) { '(not set)' } else { "$($b.Value)" }

                $conflicts.Add([PSCustomObject]@{
                    PSTypeName    = 'LKPolicyConflict'
                    SettingName   = $settingName
                    PolicyA       = $a.PolicyName
                    PolicyAType   = $a.PolicyType
                    ValueA        = $valA
                    PolicyB       = $b.PolicyName
                    PolicyBType   = $b.PolicyType
                    ValueB        = $valB
                    ValueMatch    = $valA -eq $valB
                    CommonGroups  = $commonGroups.Count
                    CommonGroupIds = $commonGroups
                })
            }
        }
    }

    Write-Progress -Activity 'Scanning for policy conflicts' -Completed

    if ($conflicts.Count -eq 0) {
        Write-Host ''
        Write-Host '  No policy conflicts detected.' -ForegroundColor Green
        Write-Host ''
        return
    }

    # Sort: value mismatches first, then by setting name
    $conflicts = $conflicts | Sort-Object { -not $_.ValueMatch }, SettingName, PolicyA

    if ($Detailed) {
        $conflicts
    } else {
        # Table view: show conflicts grouped by severity
        $mismatches = @($conflicts | Where-Object { -not $_.ValueMatch })
        $matches = @($conflicts | Where-Object { $_.ValueMatch })

        if ($mismatches.Count -gt 0) {
            Write-Host ''
            Write-Host "  CONFLICTING VALUES ($($mismatches.Count))" -ForegroundColor Red
            $displayData = $mismatches | ForEach-Object {
                [PSCustomObject]@{
                    Setting = if ($_.SettingName.Length -gt 35) { $_.SettingName.Substring(0, 32) + '...' } else { $_.SettingName }
                    PolicyA = if ($_.PolicyA.Length -gt 25) { $_.PolicyA.Substring(0, 22) + '...' } else { $_.PolicyA }
                    ValueA  = if ($_.ValueA.Length -gt 20) { $_.ValueA.Substring(0, 17) + '...' } else { $_.ValueA }
                    PolicyB = if ($_.PolicyB.Length -gt 25) { $_.PolicyB.Substring(0, 22) + '...' } else { $_.PolicyB }
                    ValueB  = if ($_.ValueB.Length -gt 20) { $_.ValueB.Substring(0, 17) + '...' } else { $_.ValueB }
                    Groups  = $_.CommonGroups
                }
            }
            Write-LKTable -Data $displayData -Columns @('Setting', 'PolicyA', 'ValueA', 'PolicyB', 'ValueB', 'Groups')
        }

        if ($matches.Count -gt 0) {
            Write-Host "  DUPLICATE SETTINGS - same value ($($matches.Count))" -ForegroundColor Yellow
            $displayData = $matches | ForEach-Object {
                [PSCustomObject]@{
                    Setting = if ($_.SettingName.Length -gt 35) { $_.SettingName.Substring(0, 32) + '...' } else { $_.SettingName }
                    Value   = if ($_.ValueA.Length -gt 20) { $_.ValueA.Substring(0, 17) + '...' } else { $_.ValueA }
                    PolicyA = if ($_.PolicyA.Length -gt 25) { $_.PolicyA.Substring(0, 22) + '...' } else { $_.PolicyA }
                    PolicyB = if ($_.PolicyB.Length -gt 25) { $_.PolicyB.Substring(0, 22) + '...' } else { $_.PolicyB }
                    Groups  = $_.CommonGroups
                }
            }
            Write-LKTable -Data $displayData -Columns @('Setting', 'Value', 'PolicyA', 'PolicyB', 'Groups')
        }

        Write-Host ''
        Write-Host "  $($conflicts.Count) conflict(s) found: $($mismatches.Count) with different values, $($matches.Count) duplicates." -ForegroundColor Gray
        Write-Host ''
    }
}
