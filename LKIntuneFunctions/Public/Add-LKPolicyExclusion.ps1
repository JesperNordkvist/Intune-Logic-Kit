function Add-LKPolicyExclusion {
    <#
    .SYNOPSIS
        Adds a group as an exclusion to one or more Intune policies.
    .DESCRIPTION
        For each target policy: fetches current assignments, appends an exclusion entry,
        and writes back the complete set (replace-all pattern). Skips policies that
        already exclude the group. Always confirms before modifying.
    .EXAMPLE
        Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
    .EXAMPLE
        Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All -PolicyType CompliancePolicy
    .EXAMPLE
        Get-LKPolicy -Name "XW365" | Add-LKPolicyExclusion -GroupName 'TestGroup'
    .EXAMPLE
        Add-LKPolicyExclusion -GroupName 'TestGroup' -All -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'All')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$PolicyType,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string[]]$PolicyName,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$SearchPolicyType
    )

    begin {
        Assert-LKSession
        $groupId = Resolve-LKGroupId -GroupName $GroupName
        $groupScope = Resolve-LKGroupScope -GroupId $groupId
        $bulkConfirmed = $false

        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $lookupParams = @{ Name = $PolicyName; NameMatch = $NameMatch }
            if ($SearchPolicyType) { $lookupParams['PolicyType'] = $SearchPolicyType }
            $resolvedPolicies = @(Get-LKPolicy @lookupParams)
            if ($resolvedPolicies.Count -eq 0) {
                Write-Warning "No policies found matching '$($PolicyName -join "', '")' with $NameMatch match."
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            foreach ($pol in $resolvedPolicies) {
                $confirmParam = @{}
                if ($PSBoundParameters.ContainsKey('Confirm')) { $confirmParam['Confirm'] = $PSBoundParameters['Confirm'] }
                Add-LKPolicyExclusion -InputObject $pol -GroupName $GroupName @confirmParam
            }
            return
        }

        if ($All) {
            $policies = @(Get-LKPolicy -PolicyType:$PolicyType)

            $typeList = ($policies | Select-Object -ExpandProperty DisplayType -Unique) -join ', '
            Write-LKActionSummary -Action 'ADD EXCLUSION TO ALL POLICIES' -Details ([ordered]@{
                Group    = "$GroupName (Exclude)"
                Policies = "$($policies.Count) policies found"
                Types    = $typeList
            })

            if (-not $PSCmdlet.ShouldProcess("$($policies.Count) policies", "Add exclusion for '$GroupName' to ALL")) {
                return
            }
            $bulkConfirmed = $true
        } elseif ($InputObject) {
            $policies = @($InputObject)
        } else {
            return
        }

        foreach ($policy in $policies) {
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $policy.PolicyType }
            if (-not $typeEntry) { continue }

            if ($typeEntry.AssignmentMethod -eq 'GroupAssignments') {
                Write-Verbose "Skipping '$($policy.Name)' - policy type does not support exclusions."
                continue
            }

            $assignments = Get-LKRawAssignment -PolicyId $policy.Id -PolicyType $typeEntry

            $alreadyExcluded = $assignments | Where-Object {
                $_.target.'@odata.type' -like '*exclusionGroupAssignmentTarget' -and
                $_.target.groupId -eq $groupId
            }
            if ($alreadyExcluded) {
                Write-Verbose "Skipping '$($policy.Name)' - group already excluded."
                continue
            }

            # Scope mismatch check - skip if scopes are incompatible
            $policyScope = if ($policy.TargetScope) { $policy.TargetScope } else { $typeEntry.TargetScope }
            if ($groupScope -ne 'Unknown' -and $policyScope -ne 'Both' -and $groupScope -ne $policyScope) {
                Write-Warning "Skipping '$($policy.Name)': group '$GroupName' is a $groupScope group, but policy is $policyScope-scoped."
                continue
            }

            $shouldProceed = $bulkConfirmed
            if (-not $shouldProceed) {
                Write-LKActionSummary -Action 'ADD EXCLUSION' -Details ([ordered]@{
                    Policy = "$($policy.Name) ($($typeEntry.DisplayName))"
                    Group  = "$GroupName (Exclude)"
                    Scope  = "Policy=$policyScope, Group=$groupScope"
                })
                $shouldProceed = $PSCmdlet.ShouldProcess("$($policy.Name) ($($typeEntry.DisplayName))", "Add exclusion for '$GroupName'")
            }

            if ($shouldProceed) {
                $newExclusion = @{
                    target = @{
                        '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'
                        groupId       = $groupId
                    }
                }

                $updatedAssignments = @($assignments) + @($newExclusion)

                try {
                    Set-LKRawAssignment -PolicyId $policy.Id -PolicyType $typeEntry -Assignments $updatedAssignments
                    [PSCustomObject]@{
                        PolicyName = $policy.Name
                        PolicyType = $typeEntry.TypeName
                        Action     = 'ExclusionAdded'
                        GroupName  = $GroupName
                        GroupId    = $groupId
                    }
                } catch {
                    $err = $_.Exception.Message
                    Write-Warning "Failed to add exclusion to '$($policy.Name)': $err"
                }
            }
        }
    }
}
