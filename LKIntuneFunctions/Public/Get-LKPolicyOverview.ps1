function Get-LKPolicyOverview {
    <#
    .SYNOPSIS
        Displays a formatted overview of all policies and their assignments at a glance.
    .DESCRIPTION
        Queries all (or filtered) policies, fetches their assignments, and renders a
        color-coded summary with one line per assignment, grouped by policy.

        Policies with no assignments are shown in dark gray.
        Excludes are highlighted in magenta, broad targets in cyan.
    .EXAMPLE
        Get-LKPolicyOverview
        Shows all policies and their assignments.
    .EXAMPLE
        Get-LKPolicyOverview -PolicyType SettingsCatalog
        Shows only Settings Catalog policies.
    .EXAMPLE
        Get-LKPolicyOverview -Name "XW365 - Win - SC"
        Shows policies matching the name filter.
    .EXAMPLE
        Get-LKPolicyOverview -Unassigned
        Shows only policies that have no assignments.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Name,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$PolicyType,

        [switch]$Unassigned
    )

    Assert-LKSession

    # Build Get-LKPolicy params
    $policyParams = @{}
    if ($Name) { $policyParams['Name'] = $Name; $policyParams['NameMatch'] = $NameMatch }
    if ($PolicyType) { $policyParams['PolicyType'] = $PolicyType }

    $policies = @(Get-LKPolicy @policyParams)
    if ($policies.Count -eq 0) {
        Write-Warning "No policies found."
        return
    }

    $totalPolicies = $policies.Count
    $currentPolicy = 0
    $groupNameCache = @{}

    # Collect all data first, then render
    $policyData = [System.Collections.ArrayList]::new()

    foreach ($pol in $policies) {
        $currentPolicy++
        Write-Progress -Activity 'Building policy overview' `
            -Status "$($pol.Name) ($currentPolicy of $totalPolicies)" `
            -PercentComplete (($currentPolicy / $totalPolicies) * 100)

        try {
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $pol.PolicyType }
            $rawAssignments = Get-LKRawAssignment -PolicyId $pol.Id -PolicyType $typeEntry
        } catch {
            $rawAssignments = @()
        }

        $assignments = @()
        foreach ($a in $rawAssignments) {
            $target = $a.target
            if (-not $target) { continue }

            $odataType = $target.'@odata.type'

            $assignmentType = switch -Wildcard ($odataType) {
                '*exclusionGroupAssignmentTarget'   { 'Exclude'; break }
                '*groupAssignmentTarget'            { 'Include'; break }
                '*allDevicesAssignmentTarget'        { 'AllDevices'; break }
                '*allUsersAssignmentTarget'          { 'AllUsers'; break }
                '*allLicensedUsersAssignmentTarget'  { 'AllLicensedUsers'; break }
                default                              { 'Unknown' }
            }

            $groupId   = $target.groupId
            $groupName = $null

            if ($groupId) {
                if ($groupNameCache.ContainsKey($groupId)) {
                    $groupName = $groupNameCache[$groupId]
                } else {
                    try {
                        $grp = Invoke-LKGraphRequest -Method GET `
                            -Uri "/groups/$groupId`?`$select=displayName" -ApiVersion 'v1.0'
                        $groupName = if ($grp.displayName) { $grp.displayName } else { $groupId }
                    } catch {
                        $groupName = $groupId
                    }
                    $groupNameCache[$groupId] = $groupName
                }
            }

            $assignments += @{
                Type      = $assignmentType
                GroupName = $groupName
            }
        }

        $policyData.Add(@{
            Name        = $pol.Name
            DisplayType = $pol.DisplayType
            Assignments = $assignments
        }) | Out-Null
    }

    Write-Progress -Activity 'Building policy overview' -Completed

    # Render
    $separator = '=' * 80
    Write-Host ''
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "  POLICY OVERVIEW" -ForegroundColor White
    Write-Host $separator -ForegroundColor DarkGray

    $totalAssigned   = @($policyData | Where-Object { $_.Assignments.Count -gt 0 }).Count
    $totalUnassigned = @($policyData | Where-Object { $_.Assignments.Count -eq 0 }).Count
    Write-Host ''
    Write-Host "  Policies: $($policyData.Count) total, " -ForegroundColor Gray -NoNewline
    Write-Host "$totalAssigned assigned" -ForegroundColor Green -NoNewline
    Write-Host ", " -ForegroundColor Gray -NoNewline
    Write-Host "$totalUnassigned unassigned" -ForegroundColor $(if ($totalUnassigned -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host ''

    $filteredData = if ($Unassigned) {
        @($policyData | Where-Object { $_.Assignments.Count -eq 0 })
    } else {
        $policyData
    }

    foreach ($pol in $filteredData) {
        $typeLabel = $pol.DisplayType
        Write-Host "  $($pol.Name)" -ForegroundColor White -NoNewline
        Write-Host "  ($typeLabel)" -ForegroundColor DarkGray

        if ($pol.Assignments.Count -eq 0) {
            Write-Host "    (no assignments)" -ForegroundColor DarkGray
        } else {
            foreach ($a in $pol.Assignments) {
                $label = if ($a.GroupName) { "$($a.Type): $($a.GroupName)" } else { $a.Type }
                $color = switch ($a.Type) {
                    'Exclude'          { 'Magenta' }
                    'AllDevices'       { 'Cyan' }
                    'AllUsers'         { 'Cyan' }
                    'AllLicensedUsers' { 'Cyan' }
                    'Include'          { 'Gray' }
                    default            { 'DarkGray' }
                }
                Write-Host "    $label" -ForegroundColor $color
            }
        }
        Write-Host ''
    }

    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ''
}
