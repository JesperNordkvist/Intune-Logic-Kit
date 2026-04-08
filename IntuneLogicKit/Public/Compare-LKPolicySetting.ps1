function Compare-LKPolicySetting {
    <#
    .SYNOPSIS
        Compares settings between two or more policies side by side.
    .DESCRIPTION
        Fetches settings for each policy and shows differences. By default only shows
        settings that differ between policies. Use -IncludeEqual to show all settings.
        Accepts pipeline input from Get-LKPolicy.
    .EXAMPLE
        Get-LKPolicy -Name "Baseline" -NameMatch Contains | Compare-LKPolicySetting
        Compares all policies with "Baseline" in the name.
    .EXAMPLE
        Compare-LKPolicySetting -PolicyId 'abc-123', 'def-456'
        Compares two policies by ID.
    .EXAMPLE
        Get-LKPolicy -Name "Firewall" | Compare-LKPolicySetting -IncludeEqual
        Shows all settings, including those that match across policies.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string[]]$PolicyId,

        [switch]$IncludeEqual,

        [ValidateSet('Table', 'List')]
        [string]$DisplayAs = 'Table'
    )

    begin {
        Assert-LKSession
        $policies = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($InputObject) {
            $policies.Add($InputObject)
        }
    }

    end {
        # Resolve by ID if not using pipeline
        if ($PolicyId) {
            foreach ($id in $PolicyId) {
                try {
                    $resolved = Resolve-LKPolicyTypeById -PolicyId $id
                    $obj = ConvertTo-LKPolicyObject -RawPolicy $resolved.RawPolicy -PolicyType $resolved.TypeEntry
                    $obj | Add-Member -NotePropertyName '_RawForCompare' -NotePropertyValue $resolved.RawPolicy
                    $obj | Add-Member -NotePropertyName '_TypeEntryForCompare' -NotePropertyValue $resolved.TypeEntry
                    $policies.Add($obj)
                } catch {
                    Write-Warning "Could not resolve policy '$id': $($_.Exception.Message)"
                }
            }
        }

        if ($policies.Count -lt 2) {
            Write-Warning "At least 2 policies are required for comparison. Got $($policies.Count)."
            return
        }

        # Fetch settings for each policy
        $policySettings = [ordered]@{}
        $allSettingNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $count = 0
        foreach ($policy in $policies) {
            $count++
            Write-Progress -Activity 'Comparing policy settings' -Status "$($policy.Name) ($count of $($policies.Count))" -PercentComplete (($count / $policies.Count) * 100)

            $typeEntry = if ($policy._TypeEntryForCompare) {
                $policy._TypeEntryForCompare
            } else {
                $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $policy.PolicyType }
            }

            $raw = if ($policy._RawForCompare) {
                $policy._RawForCompare
            } else {
                $policy.RawObject
            }

            if (-not $typeEntry) {
                Write-Warning "Could not resolve type for '$($policy.Name)'. Skipping."
                continue
            }

            try {
                $settings = Get-LKPolicySettings -PolicyId $policy.Id -PolicyType $typeEntry -RawPolicy $raw
            } catch {
                Write-Warning "Failed to fetch settings for '$($policy.Name)': $($_.Exception.Message)"
                $settings = @()
            }

            $settingsMap = @{}
            foreach ($s in $settings) {
                $settingsMap[$s.Name] = $s.Value
                $allSettingNames.Add($s.Name) | Out-Null
            }
            $policySettings[$policy.Name] = $settingsMap
        }

        Write-Progress -Activity 'Comparing policy settings' -Completed

        # Build comparison results
        $policyNames = @($policySettings.Keys)
        $results = [System.Collections.Generic.List[object]]::new()

        foreach ($settingName in ($allSettingNames | Sort-Object)) {
            $values = @{}
            foreach ($pName in $policyNames) {
                $val = $policySettings[$pName][$settingName]
                $values[$pName] = if ($null -eq $val) { $null } else { "$val" }
            }

            # Check if all values are the same
            $distinctValues = @($values.Values | Where-Object { $null -ne $_ } | Select-Object -Unique)
            $allPresent = @($values.Values | Where-Object { $null -ne $_ }).Count -eq $policyNames.Count
            $isEqual = $allPresent -and $distinctValues.Count -le 1

            if (-not $IncludeEqual -and $isEqual) { continue }

            $obj = [PSCustomObject]@{
                PSTypeName  = 'LKSettingComparison'
                SettingName = $settingName
                Status      = if ($isEqual) { 'Equal' }
                              elseif (-not $allPresent) { 'Missing' }
                              else { 'Different' }
            }

            foreach ($pName in $policyNames) {
                $displayVal = $values[$pName]
                if ($null -eq $displayVal) { $displayVal = '(not configured)' }
                elseif ($displayVal -eq 'True')  { $displayVal = 'Enabled' }
                elseif ($displayVal -eq 'False') { $displayVal = 'Disabled' }
                $obj | Add-Member -NotePropertyName $pName -NotePropertyValue $displayVal
            }

            $results.Add($obj)
        }

        if ($results.Count -eq 0) {
            Write-Host ''
            if ($IncludeEqual) {
                Write-Host '  No settings found across the selected policies.' -ForegroundColor DarkGray
            } else {
                Write-Host '  All settings are identical across the selected policies.' -ForegroundColor Green
            }
            Write-Host ''
            return
        }

        if ($DisplayAs -eq 'List') {
            $results
        } else {
            $columns = @('SettingName', 'Status') + $policyNames
            $colorRules = @{
                'Status' = @{
                    'Equal'     = 'Green'
                    'Different' = 'Yellow'
                    'Missing'   = 'DarkGray'
                }
            }

            # Truncate for display
            $displayData = $results | ForEach-Object {
                $row = [PSCustomObject]@{
                    SettingName = if ($_.SettingName.Length -gt 40) { $_.SettingName.Substring(0, 37) + '...' } else { $_.SettingName }
                    Status      = $_.Status
                }
                foreach ($pName in $policyNames) {
                    $val = $_.$pName
                    $truncName = if ($pName.Length -gt 25) { $pName.Substring(0, 22) + '...' } else { $pName }
                    if ($val.Length -gt 30) { $val = $val.Substring(0, 27) + '...' }
                    $row | Add-Member -NotePropertyName $truncName -NotePropertyValue $val
                }
                $row
            }

            $displayColumns = @('SettingName', 'Status') + @($policyNames | ForEach-Object {
                if ($_.Length -gt 25) { $_.Substring(0, 22) + '...' } else { $_ }
            })

            Write-LKTable -Data $displayData -Columns $displayColumns -ColorRules $colorRules
            Write-Host "  $($results.Count) setting(s) shown ($(@($results | Where-Object Status -eq 'Different').Count) different, $(@($results | Where-Object Status -eq 'Missing').Count) missing)." -ForegroundColor Gray
            Write-Host ''
        }
    }
}
