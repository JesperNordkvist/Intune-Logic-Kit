function Resolve-LKPolicyScope {
    <#
    .SYNOPSIS
        Determines the effective assignment scope (User/Device/Both) of a policy.
        This reflects which group types a policy can validly be assigned to,
        not the CSP scope (HKLM vs HKCU) of its underlying settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RawPolicy,

        [Parameter(Mandatory)]
        [hashtable]$PolicyType
    )

    # Fast path: types with a fixed, known scope
    if ($PolicyType.TargetScope -ne 'Both') {
        return $PolicyType.TargetScope
    }

    switch ($PolicyType.TypeName) {

        'SettingsCatalog' {
            # Settings Catalog definition ID prefixes (device_ / user_) indicate CSP scope
            # (HKLM vs HKCU), NOT assignment scope. Intune fully supports cross-scope:
            #   - device_ CSP policies assigned to user groups (applies HKLM when user signs in)
            #   - user_ CSP policies assigned to device groups (applies to all users on device)
            # OIB deliberately assigns device_ CSP policies to user groups for Autopilot timing.
            # Fall through to name-based heuristic.
        }

        'EndpointSecurity' {
            # Cache template lookups within the module session
            if (-not $script:LKTemplateCache) { $script:LKTemplateCache = @{} }

            $templateId = $RawPolicy.templateId
            if ($templateId) {
                if (-not $script:LKTemplateCache.ContainsKey($templateId)) {
                    try {
                        $script:LKTemplateCache[$templateId] = Invoke-LKGraphRequest -Method GET `
                            -Uri "/deviceManagement/templates/$templateId" -ApiVersion 'beta'
                    } catch {
                        $script:LKTemplateCache[$templateId] = $null
                    }
                }

                $template = $script:LKTemplateCache[$templateId]
                if ($template) {
                    $deviceSubtypes = @(
                        'firewall', 'diskEncryption', 'attackSurfaceReduction',
                        'endpointDetectionResponse', 'antivirus', 'accountProtection'
                    )
                    if ($template.templateSubtype -in $deviceSubtypes) { return 'Device' }

                    $deviceTypes = @(
                        'securityBaseline', 'advancedThreatProtectionSecurityBaseline',
                        'microsoftEdgeSecurityBaseline'
                    )
                    if ($template.templateType -in $deviceTypes) { return 'Device' }
                }
            }

            return 'Device'
        }

        'GroupPolicyConfiguration' {
            # Check the classType on the first definition value
            try {
                $defValuesResponse = Invoke-LKGraphRequest -Method GET `
                    -Uri "/deviceManagement/groupPolicyConfigurations/$($RawPolicy.id)/definitionValues?`$expand=definition&`$top=1" `
                    -ApiVersion 'beta'
                $defValuesList = $defValuesResponse.value
                if ($defValuesList -and $defValuesList.Count -gt 0) {
                    $classType = $defValuesList[0].definition.classType
                    if ($classType -eq 'user')    { return 'User' }
                    if ($classType -eq 'machine') { return 'Device' }
                }
            } catch {
                Write-Verbose "Resolve-LKPolicyScope: failed to fetch definition values for ADMX policy $($RawPolicy.id): $($_.Exception.Message)"
            }
            # Fall through to name-based heuristic
        }

        'EnrollmentConfiguration' {
            $odataType = $RawPolicy.'@odata.type'
            if ($odataType -like '*Limit*')               { return 'User' }
            if ($odataType -like '*HelloForBusiness*')     { return 'User' }
            # Fall through to name-based heuristic
        }

        'DeviceConfiguration' {
            # Most device configs can be assigned to either, but some are clearly device-only
            $odataType = $RawPolicy.'@odata.type'
            $deviceOnly = @(
                '*windowsUpdateForBusinessConfiguration*',
                '*sharedPCConfiguration*',
                '*editionUpgradeConfiguration*',
                '*windowsDefenderAdvancedThreatProtection*',
                '*windowsKioskConfiguration*'
            )
            foreach ($pattern in $deviceOnly) {
                if ($odataType -like $pattern) { return 'Device' }
            }
            # Fall through to name-based heuristic
        }

        default { }  # Fall through to name-based heuristic below
    }

    # Final fallback: infer scope from naming convention
    # Common patterns: "- U -", "-U-", "- D -", "-D-", "- C -", "-C-"
    #   U = User-scoped, D/C = Device-scoped (C = Computer)
    $nameProp = $PolicyType.NameProperty
    $policyName = $RawPolicy.$nameProp
    if ($policyName) {
        if ($policyName -match '[-–]\s*U\s*[-–]') { return 'User' }
        if ($policyName -match '[-–]\s*[DC]\s*[-–]') { return 'Device' }
    }

    return 'Both'
}
