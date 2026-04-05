function Show-LKPolicyDetail {
    <#
    .SYNOPSIS
        Displays a detailed, formatted view of one or more Intune policies including all configured settings.
    .DESCRIPTION
        Fetches the full settings for each policy and renders them in a readable grouped format.
        Accepts pipeline input from Get-LKPolicy.
    .EXAMPLE
        Get-LKPolicy -Name "XW365 - Baseline" -NameMatch Contains | Show-LKPolicyDetail
    .EXAMPLE
        Get-LKPolicy -PolicyType SettingsCatalog -Name "Firewall" | Show-LKPolicyDetail
    .EXAMPLE
        Show-LKPolicyDetail -PolicyId 'abc-123' -PolicyType SettingsCatalog
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

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
        [string]$PolicyType
    )

    begin {
        Assert-LKSession
    }

    process {
        if ($InputObject) {
            $id   = $InputObject.Id
            $name = $InputObject.Name
            $desc = $InputObject.Description
            $displayType = $InputObject.DisplayType
            $scope = $InputObject.TargetScope
            $created = $InputObject.CreatedAt
            $modified = $InputObject.ModifiedAt
            $raw = $InputObject.RawObject
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $InputObject.PolicyType }
        } elseif ($PolicyType) {
            $id   = $PolicyId
            $name = $null; $desc = $null; $displayType = $null
            $scope = $null; $created = $null; $modified = $null; $raw = $null
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $PolicyType }
        } else {
            try {
                $resolved = Resolve-LKPolicyTypeById -PolicyId $PolicyId
                $id        = $PolicyId
                $typeEntry = $resolved.TypeEntry
                $raw       = $resolved.RawPolicy
                $name      = $resolved.PolicyName
                $desc      = $raw.description
                $displayType = $typeEntry.DisplayName
                $scope     = $typeEntry.TargetScope
                $created   = $raw.createdDateTime
                $modified  = $raw.lastModifiedDateTime
            } catch {
                Write-Warning $_.Exception.Message
                return
            }
        }

        if (-not $typeEntry) {
            Write-Warning "Could not resolve policy type for '$id'."
            return
        }

        # If we don't have the raw object (ById path), fetch it
        if (-not $raw) {
            try {
                $raw = Invoke-LKGraphRequest -Method GET -Uri "$($typeEntry.Endpoint)/$id" -ApiVersion $typeEntry.ApiVersion
                $nameProp = $typeEntry.NameProperty
                $name = $raw.$nameProp
                $desc = $raw.description
                $displayType = $typeEntry.DisplayName
                $scope = $typeEntry.TargetScope
                $created = $raw.createdDateTime
                $modified = $raw.lastModifiedDateTime
            } catch {
                Write-Warning "Failed to fetch policy $id`: $($_.Exception.Message)"
                return
            }
        }

        if (-not $displayType) { $displayType = $typeEntry.DisplayName }
        if (-not $scope) { $scope = $typeEntry.TargetScope }

        # Fetch settings
        $settings = Get-LKPolicySettings -PolicyId $id -PolicyType $typeEntry -RawPolicy $raw

        # Fetch assignments
        $assignments = @()
        try {
            $rawAssignments = Get-LKRawAssignment -PolicyId $id -PolicyType $typeEntry
            foreach ($a in $rawAssignments) {
                $target = $a.target
                if (-not $target) { continue }
                $aType = switch -Wildcard ($target.'@odata.type') {
                    '*exclusionGroupAssignmentTarget' { 'Exclude' }
                    '*groupAssignmentTarget'          { 'Include' }
                    '*allDevicesAssignmentTarget'      { 'All Devices' }
                    '*allUsersAssignmentTarget'        { 'All Users' }
                    '*allLicensedUsersAssignmentTarget' { 'All Licensed Users' }
                    default                            { 'Unknown' }
                }
                $gName = $target.groupId
                if ($target.groupId) {
                    try {
                        $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$($target.groupId)?`$select=displayName" -ApiVersion 'v1.0'
                        $gName = $grp.displayName
                    } catch { }
                }
                $assignments += @{ Type = $aType; Target = $gName }
            }
        } catch {
            Write-Verbose "Failed to fetch assignments: $($_.Exception.Message)"
        }

        # ── Render ──
        $separator = '─' * 70
        Write-Host ''
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host "  $name" -ForegroundColor White
        Write-Host $separator -ForegroundColor DarkGray

        # Header info
        $headerItems = [ordered]@{
            'Type'     = $displayType
            'Scope'    = $scope
            'Created'  = $created
            'Modified' = $modified
        }
        if ($desc) { $headerItems['Description'] = $desc }
        $headerItems['Id'] = $id

        foreach ($key in $headerItems.Keys) {
            $value = $headerItems[$key]
            if ($value) {
                Write-Host "  $($key.PadRight(12))" -ForegroundColor Gray -NoNewline
                Write-Host "$value" -ForegroundColor Cyan
            }
        }

        # Assignments section
        Write-Host ''
        Write-Host '  ASSIGNMENTS' -ForegroundColor Yellow
        if ($assignments.Count -eq 0) {
            Write-Host '    (none)' -ForegroundColor DarkGray
        } else {
            foreach ($a in $assignments) {
                $color = switch ($a.Type) {
                    'Include' { 'Green' }
                    'Exclude' { 'Red' }
                    default   { 'White' }
                }
                Write-Host "    [$($a.Type)]" -ForegroundColor $color -NoNewline
                Write-Host " $($a.Target)" -ForegroundColor White
            }
        }

        # Settings section
        Write-Host ''
        Write-Host '  SETTINGS' -ForegroundColor Yellow
        if (-not $settings -or $settings.Count -eq 0) {
            Write-Host '    (no settings found or policy type does not expose individual settings)' -ForegroundColor DarkGray
        } else {
            # Group by category
            $grouped = $settings | Group-Object { $_.Category }
            $maxNameLen = ($settings | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
            $maxNameLen = [Math]::Min($maxNameLen, 65)

            foreach ($group in $grouped) {
                if ($grouped.Count -gt 1) {
                    Write-Host ''
                    Write-Host "    [$($group.Name)]" -ForegroundColor DarkYellow
                }

                foreach ($s in $group.Group) {
                    $settingName = $s.Name
                    if ($settingName.Length -gt 65) {
                        $settingName = $settingName.Substring(0, 62) + '...'
                    }
                    $paddedName = $settingName.PadRight($maxNameLen)

                    $displayValue = if ($null -eq $s.Value -or "$($s.Value)" -eq '') {
                        '(not set)'
                    } elseif ("$($s.Value)" -eq 'True') {
                        'Yes'
                    } elseif ("$($s.Value)" -eq 'False') {
                        'No'
                    } else {
                        "$($s.Value)".TrimEnd('.')
                    }

                    # Truncate very long values
                    if ($displayValue.Length -gt 80) {
                        $displayValue = $displayValue.Substring(0, 77) + '...'
                    }

                    Write-Host "    $paddedName  " -ForegroundColor Gray -NoNewline
                    Write-Host $displayValue -ForegroundColor White
                }
            }
        }

        Write-Host ''
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host ''
    }
}
