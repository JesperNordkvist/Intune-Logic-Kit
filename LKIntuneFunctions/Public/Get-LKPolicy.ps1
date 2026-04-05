function Get-LKPolicy {
    <#
    .SYNOPSIS
        Queries Intune policies across all or specific policy types with flexible name filtering.
    .EXAMPLE
        Get-LKPolicy -Name "XW365" -NameMatch Contains
    .EXAMPLE
        Get-LKPolicy -PolicyType SettingsCatalog, CompliancePolicy
    .EXAMPLE
        Get-LKPolicy -Name "Baseline*" -NameMatch Wildcard -FilterScript { $_.TargetScope -eq 'Device' }
    .EXAMPLE
        Get-LKPolicy -ResolveScope
        Returns all policies with accurate User/Device scope resolved via Graph metadata.
    .EXAMPLE
        Get-LKPolicy -Name "Baseline" -IncludeSettings
        Returns policies with their configured settings attached as a Settings property.
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
            'GroupPolicyConfiguration', 'PowerShellScript', 'ProactiveRemediation',
            'DriverUpdate', 'MobileApp'
        )]
        [string[]]$PolicyType,

        [switch]$ResolveScope,

        [switch]$IncludeSettings,

        [scriptblock]$FilterScript
    )

    Assert-LKSession

    $types = if ($PolicyType) {
        $script:LKPolicyTypes | Where-Object { $_.TypeName -in $PolicyType }
    } else {
        $script:LKPolicyTypes
    }

    $totalTypes = $types.Count
    $currentType = 0

    foreach ($type in $types) {
        $currentType++
        Write-Progress -Activity 'Querying Intune policies' -Status "$($type.DisplayName) ($currentType of $totalTypes)" -PercentComplete (($currentType / $totalTypes) * 100)

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

            if ($Name -and -not (Test-LKNameMatch -Value $policyName -Name $Name -NameMatch $NameMatch)) {
                continue
            }

            $resolvedScope = $null
            if ($ResolveScope) {
                $resolvedScope = Resolve-LKPolicyScope -RawPolicy $raw -PolicyType $type
            }

            $obj = ConvertTo-LKPolicyObject -RawPolicy $raw -PolicyType $type -ResolvedScope $resolvedScope

            if ($FilterScript -and -not ($obj | Where-Object $FilterScript)) {
                continue
            }

            if ($IncludeSettings) {
                $rawSettings = Get-LKPolicySettings -PolicyId $raw.id -PolicyType $type -RawPolicy $raw
                $settings = @($rawSettings | ForEach-Object {
                    [PSCustomObject]@{
                        PSTypeName = 'LKPolicySetting'
                        Name       = $_.Name
                        Value      = $_.Value
                        Category   = $_.Category
                    }
                })
                $obj | Add-Member -NotePropertyName 'Settings' -NotePropertyValue $settings
            }

            $obj
        }
    }

    Write-Progress -Activity 'Querying Intune policies' -Completed
}
