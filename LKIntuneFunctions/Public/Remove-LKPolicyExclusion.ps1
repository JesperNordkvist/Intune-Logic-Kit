function Remove-LKPolicyExclusion {
    <#
    .SYNOPSIS
        Removes a group exclusion from one or more Intune policies.
    .EXAMPLE
        Remove-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
    .EXAMPLE
        Get-LKPolicy -Name "XW365" | Remove-LKPolicyExclusion -GroupName 'TestGroup'
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
                Remove-LKPolicyExclusion -InputObject $pol -GroupName $GroupName @confirmParam
            }
            return
        }

        if ($All) {
            $policies = @(Get-LKPolicy -PolicyType:$PolicyType)

            $typeList = ($policies | Select-Object -ExpandProperty DisplayType -Unique) -join ', '
            Write-LKActionSummary -Action 'REMOVE EXCLUSION FROM ALL POLICIES' -Details ([ordered]@{
                Group    = "$GroupName (Exclude)"
                Policies = "$($policies.Count) policies found"
                Types    = $typeList
            })

            if (-not $PSCmdlet.ShouldProcess("$($policies.Count) policies", "Remove exclusion for '$GroupName' from ALL")) {
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

            $hasExclusion = $assignments | Where-Object {
                $_.target.'@odata.type' -like '*exclusionGroupAssignmentTarget' -and
                $_.target.groupId -eq $groupId
            }
            if (-not $hasExclusion) {
                Write-Verbose "Skipping '$($policy.Name)' - group is not excluded."
                continue
            }

            $shouldProceed = $bulkConfirmed
            if (-not $shouldProceed) {
                Write-LKActionSummary -Action 'REMOVE EXCLUSION' -Details ([ordered]@{
                    Policy = "$($policy.Name) ($($typeEntry.DisplayName))"
                    Group  = "$GroupName (Exclude)"
                })
                $shouldProceed = $PSCmdlet.ShouldProcess("$($policy.Name) ($($typeEntry.DisplayName))", "Remove exclusion for '$GroupName'")
            }

            if ($shouldProceed) {
                $updatedAssignments = @($assignments | Where-Object {
                    -not ($_.target.'@odata.type' -like '*exclusionGroupAssignmentTarget' -and $_.target.groupId -eq $groupId)
                })

                try {
                    Set-LKRawAssignment -PolicyId $policy.Id -PolicyType $typeEntry -Assignments $updatedAssignments
                    [PSCustomObject]@{
                        PolicyName = $policy.Name
                        PolicyType = $typeEntry.TypeName
                        Action     = 'ExclusionRemoved'
                        GroupName  = $GroupName
                        GroupId    = $groupId
                    }
                } catch {
                    $err = $_.Exception.Message
                    Write-Warning "Failed to remove exclusion from '$($policy.Name)': $err"
                }
            }
        }
    }
}
