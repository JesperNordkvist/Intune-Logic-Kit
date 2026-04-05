function Remove-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Removes a group include assignment from one or more Intune policies.
    .EXAMPLE
        Get-LKPolicy -Name "XW365 - TestConfig" | Remove-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Remove-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,

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
        [string]$PolicyType,

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
                Remove-LKPolicyAssignment -InputObject $pol -GroupName $GroupName @confirmParam
            }
            return
        }

        if ($InputObject) {
            $id   = $InputObject.Id
            $name = $InputObject.Name
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $InputObject.PolicyType }
        } elseif ($PolicyType) {
            $id   = $PolicyId
            $name = $PolicyId
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $PolicyType }
        } else {
            try {
                $resolved = Resolve-LKPolicyTypeById -PolicyId $PolicyId
                $id        = $PolicyId
                $name      = $resolved.PolicyName
                $typeEntry = $resolved.TypeEntry
            } catch {
                Write-Warning $_.Exception.Message
                return
            }
        }

        if (-not $typeEntry) {
            Write-Warning "Could not resolve policy type for '$id'."
            return
        }

        $assignments = Get-LKRawAssignment -PolicyId $id -PolicyType $typeEntry

        $hasInclusion = $assignments | Where-Object {
            $_.target.'@odata.type' -like '*groupAssignmentTarget' -and
            $_.target.'@odata.type' -notlike '*exclusion*' -and
            $_.target.groupId -eq $groupId
        }
        if (-not $hasInclusion) {
            Write-Verbose "Skipping '$name' - group is not assigned."
            return
        }

        Write-LKActionSummary -Action 'REMOVE ASSIGNMENT' -Details ([ordered]@{
            Policy = "$name ($($typeEntry.DisplayName))"
            Group  = "$GroupName (Include)"
        })

        if ($PSCmdlet.ShouldProcess("$name ($($typeEntry.DisplayName))", "Remove include assignment for '$GroupName'")) {
            $updatedAssignments = @($assignments | Where-Object {
                -not (
                    $_.target.'@odata.type' -like '*groupAssignmentTarget' -and
                    $_.target.'@odata.type' -notlike '*exclusion*' -and
                    $_.target.groupId -eq $groupId
                )
            })

            try {
                Set-LKRawAssignment -PolicyId $id -PolicyType $typeEntry -Assignments $updatedAssignments
                [PSCustomObject]@{
                    PolicyName = $name
                    PolicyType = $typeEntry.TypeName
                    Action     = 'AssignmentRemoved'
                    GroupName  = $GroupName
                    GroupId    = $groupId
                }
            } catch {
                $err = $_.Exception.Message
                Write-Warning "Failed to remove assignment from '$name': $err"
            }
        }
    }
}
