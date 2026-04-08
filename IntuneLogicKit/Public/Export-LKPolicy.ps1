function Export-LKPolicy {
    <#
    .SYNOPSIS
        Exports Intune policies and their settings to JSON or CSV.
    .DESCRIPTION
        Fetches policies (with optional settings and assignments) and exports them
        to a file for documentation, auditing, or migration purposes.
        Accepts pipeline input from Get-LKPolicy.
    .EXAMPLE
        Get-LKPolicy -PolicyType SettingsCatalog | Export-LKPolicy -Path .\policies.json
        Exports all Settings Catalog policies to JSON.
    .EXAMPLE
        Get-LKPolicy -Name "Baseline" | Export-LKPolicy -Path .\baseline.csv -Format CSV
        Exports matching policies to CSV (one row per setting).
    .EXAMPLE
        Export-LKPolicy -PolicyType CompliancePolicy -IncludeSettings -Path .\compliance.json
        Exports all compliance policies with their configured settings.
    .EXAMPLE
        Export-LKPolicy -All -IncludeSettings -IncludeAssignments -Path .\full-export.json
        Full tenant export with settings and assignments.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(ParameterSetName = 'ByType')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App', 'AutopilotDeploymentProfile'
        )]
        [string[]]$PolicyType,

        [Parameter(ParameterSetName = 'ByAll')]
        [switch]$All,

        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('JSON', 'CSV')]
        [string]$Format,

        [switch]$IncludeSettings,

        [switch]$IncludeAssignments
    )

    begin {
        Assert-LKSession
        $policies = [System.Collections.Generic.List[object]]::new()

        # Auto-detect format from file extension if not specified
        if (-not $Format) {
            $ext = [System.IO.Path]::GetExtension($Path).ToLower()
            $Format = switch ($ext) {
                '.csv'  { 'CSV' }
                '.json' { 'JSON' }
                default { 'JSON' }
            }
        }
    }

    process {
        if ($InputObject) {
            $policies.Add($InputObject)
        }
    }

    end {
        # Fetch policies if not using pipeline
        if ($PolicyType -or $All) {
            $types = if ($All) { $script:LKPolicyTypes } else {
                $script:LKPolicyTypes | Where-Object { $_.TypeName -in $PolicyType }
            }

            $totalTypes = $types.Count
            $currentType = 0

            foreach ($type in $types) {
                $currentType++
                Write-Progress -Activity 'Exporting policies' -Status "$($type.DisplayName) ($currentType of $totalTypes)" -PercentComplete (($currentType / $totalTypes) * 100)

                try {
                    $rawPolicies = Invoke-LKGraphRequest -Method GET -Uri $type.Endpoint -ApiVersion $type.ApiVersion -All
                } catch {
                    Write-Warning "Failed to query $($type.DisplayName): $($_.Exception.Message)"
                    continue
                }

                foreach ($raw in $rawPolicies) {
                    $nameProp = $type.NameProperty
                    if (-not $raw.$nameProp) { continue }
                    $policies.Add((ConvertTo-LKPolicyObject -RawPolicy $raw -PolicyType $type))
                }
            }
        }

        if ($policies.Count -eq 0) {
            Write-Warning 'No policies to export.'
            return
        }

        # Enrich with settings and assignments
        $exportData = [System.Collections.Generic.List[object]]::new()
        $count = 0

        foreach ($policy in $policies) {
            $count++
            Write-Progress -Activity 'Exporting policies' -Status "$($policy.Name) ($count of $($policies.Count))" -PercentComplete (($count / $policies.Count) * 100)

            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $policy.PolicyType }

            $entry = [ordered]@{
                Name        = $policy.Name
                Id          = $policy.Id
                PolicyType  = $policy.PolicyType
                DisplayType = $policy.DisplayType
                Description = $policy.Description
                TargetScope = $policy.TargetScope
                CreatedAt   = $policy.CreatedAt
                ModifiedAt  = $policy.ModifiedAt
            }

            if ($IncludeSettings -and $typeEntry) {
                $raw = $policy.RawObject
                if (-not $raw -and $typeEntry) {
                    try {
                        $raw = Invoke-LKGraphRequest -Method GET -Uri "$($typeEntry.Endpoint)/$($policy.Id)" -ApiVersion $typeEntry.ApiVersion
                    } catch { }
                }

                try {
                    $settings = Get-LKPolicySettings -PolicyId $policy.Id -PolicyType $typeEntry -RawPolicy $raw
                    $entry['Settings'] = @($settings | ForEach-Object {
                        [ordered]@{ Name = $_.Name; Value = $_.Value; Category = $_.Category }
                    })
                } catch {
                    $entry['Settings'] = @()
                }
            }

            if ($IncludeAssignments -and $typeEntry) {
                try {
                    $rawAssignments = Get-LKRawAssignment -PolicyId $policy.Id -PolicyType $typeEntry
                    $entry['Assignments'] = @($rawAssignments | ForEach-Object {
                        $target = $_.target
                        $aType = switch -Wildcard ($target.'@odata.type') {
                            '*exclusionGroupAssignmentTarget'  { 'Exclude' }
                            '*groupAssignmentTarget'           { 'Include' }
                            '*allDevicesAssignmentTarget'      { 'All Devices' }
                            '*allUsersAssignmentTarget'        { 'All Users' }
                            '*allLicensedUsersAssignmentTarget' { 'All Licensed Users' }
                            default                            { 'Unknown' }
                        }
                        [ordered]@{
                            Type     = $aType
                            GroupId  = $target.groupId
                            Intent   = $_.intent
                            FilterId = $target.deviceAndAppManagementAssignmentFilterId
                        }
                    })
                } catch {
                    $entry['Assignments'] = @()
                }
            }

            $exportData.Add($entry)
        }

        Write-Progress -Activity 'Exporting policies' -Completed

        # Write output
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        switch ($Format) {
            'JSON' {
                $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedPath -Encoding UTF8 -Force
            }
            'CSV' {
                # Flatten: one row per setting (or one row per policy if no settings)
                $rows = [System.Collections.Generic.List[object]]::new()
                foreach ($entry in $exportData) {
                    if ($entry['Settings'] -and $entry['Settings'].Count -gt 0) {
                        foreach ($s in $entry['Settings']) {
                            $rows.Add([PSCustomObject]@{
                                PolicyName  = $entry.Name
                                PolicyType  = $entry.DisplayType
                                TargetScope = $entry.TargetScope
                                SettingName = $s.Name
                                Value       = $s.Value
                                Category    = $s.Category
                            })
                        }
                    } else {
                        $rows.Add([PSCustomObject]@{
                            PolicyName  = $entry.Name
                            PolicyType  = $entry.DisplayType
                            TargetScope = $entry.TargetScope
                            SettingName = ''
                            Value       = ''
                            Category    = ''
                        })
                    }
                }
                $rows | Export-Csv -Path $resolvedPath -NoTypeInformation -Encoding UTF8 -Force
            }
        }

        Write-Host ''
        Write-Host "  Exported $($exportData.Count) policies to $resolvedPath ($Format)" -ForegroundColor Green
        Write-Host ''
    }
}
