function Add-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Adds a group as an include assignment to one or more Intune policies.
    .EXAMPLE
        Get-LKPolicy -Name "XW365 - TestConfig" | Add-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Add-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
    .EXAMPLE
        Get-LKPolicy -Name "Google Chrome" -PolicyType App | Add-LKPolicyAssignment -GroupName 'All Users' -Intent Required
        Assigns an app as Required to a group.
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
        [string[]]$SearchPolicyType,

        [ValidateSet('Required', 'Available', 'Uninstall')]
        [string]$Intent
    )

    begin {
        Assert-LKSession
        $groupId = Resolve-LKGroupId -GroupName $GroupName
        $groupScope = Resolve-LKGroupScope -GroupId $groupId

        # ByName: resolve policies upfront
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
                $passThrough = @{}
                if ($PSBoundParameters.ContainsKey('Confirm')) { $passThrough['Confirm'] = $PSBoundParameters['Confirm'] }
                if ($Intent) { $passThrough['Intent'] = $Intent }
                Add-LKPolicyAssignment -InputObject $pol -GroupName $GroupName @passThrough
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

        $alreadyIncluded = $assignments | Where-Object {
            $_.target.'@odata.type' -like '*groupAssignmentTarget' -and
            $_.target.'@odata.type' -notlike '*exclusion*' -and
            $_.target.groupId -eq $groupId
        }
        if ($alreadyIncluded) {
            Write-Verbose "Skipping '$name' - group already assigned."
            return
        }

        # Scope mismatch check - skip the assignment if scopes are incompatible
        $policyScope = $typeEntry.TargetScope
        if ($InputObject -and $InputObject.TargetScope) { $policyScope = $InputObject.TargetScope }
        if ($groupScope -ne 'Unknown' -and $policyScope -ne 'Both' -and $groupScope -ne $policyScope) {
            Write-Warning "Skipping '$name': group '$GroupName' is a $groupScope group, but policy is $policyScope-scoped."
            return
        }

        $intentLabel = if ($Intent) { " ($Intent)" } else { '' }
        Write-LKActionSummary -Action 'ADD ASSIGNMENT' -Details ([ordered]@{
            Policy = "$name ($($typeEntry.DisplayName))"
            Group  = "$GroupName (Include)$intentLabel"
            Scope  = "Policy=$policyScope, Group=$groupScope"
        })

        if ($PSCmdlet.ShouldProcess("$name ($($typeEntry.DisplayName))", "Add include assignment for '$GroupName'$intentLabel")) {
            $newAssignment = @{
                target = @{
                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                    groupId       = $groupId
                }
            }
            if ($Intent) {
                $newAssignment['intent'] = $Intent.ToLower()
            }

            $updatedAssignments = @($assignments) + @($newAssignment)

            try {
                Set-LKRawAssignment -PolicyId $id -PolicyType $typeEntry -Assignments $updatedAssignments
                [PSCustomObject]@{
                    PolicyName = $name
                    PolicyType = $typeEntry.TypeName
                    Action     = 'AssignmentAdded'
                    GroupName  = $GroupName
                    GroupId    = $groupId
                }
            } catch {
                $err = $_.Exception.Message
                Write-Warning "Failed to add assignment to '$name': $err"
            }
        }
    }
}
