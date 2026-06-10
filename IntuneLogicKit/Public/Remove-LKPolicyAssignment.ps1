function Remove-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Removes an include assignment from one or more Intune policies.
        The target can be an Entra ID group, all devices, or all licensed users.
    .EXAMPLE
        Get-LKPolicy -Name "XW365 - TestConfig" | Remove-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Remove-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
    .EXAMPLE
        Remove-LKPolicyAssignment -PolicyName "Windows - Compliance" -NameMatch Exact -AllLicensedUsers
        Removes the All Licensed Users assignment from a policy.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter()]
        [string]$GroupName,

        [switch]$AllDevices,

        [switch]$AllLicensedUsers,

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
            'DriverUpdate', 'App', 'AutopilotDeploymentProfile'
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
            'DriverUpdate', 'App', 'AutopilotDeploymentProfile'
        )]
        [string[]]$SearchPolicyType
    )

    begin {
        Assert-LKSession -RequireWrite

        # Exactly one assignment target must be specified.
        $targetChoices = @()
        if ($GroupName)        { $targetChoices += 'GroupName' }
        if ($AllDevices)       { $targetChoices += 'AllDevices' }
        if ($AllLicensedUsers) { $targetChoices += 'AllLicensedUsers' }
        if ($targetChoices.Count -eq 0) {
            throw "An assignment target is required: specify -GroupName, -AllDevices, or -AllLicensedUsers."
        }
        if ($targetChoices.Count -gt 1) {
            throw "-GroupName, -AllDevices, and -AllLicensedUsers are mutually exclusive - specify only one."
        }

        # Resolve the chosen target into a common shape used throughout process{}.
        switch ($targetChoices[0]) {
            'AllDevices' {
                $targetKind     = 'AllDevices'
                $targetLabel    = 'All Devices'
                $targetTypeName = 'allDevicesAssignmentTarget'
                $groupId        = $null
            }
            'AllLicensedUsers' {
                $targetKind     = 'AllLicensedUsers'
                $targetLabel    = 'All Licensed Users'
                $targetTypeName = 'allLicensedUsersAssignmentTarget'
                $groupId        = $null
            }
            default {
                $targetKind     = 'Group'
                $targetLabel    = $GroupName
                $targetTypeName = 'groupAssignmentTarget'
                $groupId        = Resolve-LKGroupId -GroupName $GroupName
            }
        }

        # The target switch to forward when ByName fans out to per-policy calls.
        $targetParam = switch ($targetKind) {
            'AllDevices'       { @{ AllDevices = $true } }
            'AllLicensedUsers' { @{ AllLicensedUsers = $true } }
            default            { @{ GroupName = $GroupName } }
        }

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
                Remove-LKPolicyAssignment -InputObject $pol @targetParam @confirmParam
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

        # Broad targets cannot be expressed through the legacy group-assignment
        # API used by GroupAssignments-method policy types (e.g. Platform Scripts).
        if ($targetKind -ne 'Group' -and $typeEntry.AssignmentMethod -eq 'GroupAssignments') {
            Write-Warning "Skipping '$name': $($typeEntry.DisplayName) policies do not support the '$targetLabel' target through this module."
            return
        }

        $assignments = Get-LKRawAssignment -PolicyId $id -PolicyType $typeEntry

        $matchingAssignments = @($assignments | Where-Object {
            if ($targetKind -eq 'Group') {
                $_.target.'@odata.type' -like '*groupAssignmentTarget' -and
                $_.target.'@odata.type' -notlike '*exclusion*' -and
                $_.target.groupId -eq $groupId
            } else {
                $_.target.'@odata.type' -like "*$targetTypeName"
            }
        })
        if (-not $matchingAssignments) {
            Write-Verbose "Skipping '$name' - '$targetLabel' is not assigned."
            return
        }

        Write-LKActionSummary -Action 'REMOVE ASSIGNMENT' -Details ([ordered]@{
            Policy = "$name ($($typeEntry.DisplayName))"
            Target = "$targetLabel (Include)"
        })

        if ($PSCmdlet.ShouldProcess("$name ($($typeEntry.DisplayName))", "Remove include assignment for '$targetLabel'")) {
            # Keep every assignment except the ones matched above (matched by
            # object reference, so only the intended target is dropped).
            $updatedAssignments = @($assignments | Where-Object { $_ -notin $matchingAssignments })

            try {
                Set-LKRawAssignment -PolicyId $id -PolicyType $typeEntry -Assignments $updatedAssignments
                [PSCustomObject]@{
                    PolicyName = $name
                    PolicyType = $typeEntry.TypeName
                    Action     = 'AssignmentRemoved'
                    GroupName  = $targetLabel
                    GroupId    = $groupId
                }
            } catch {
                $err = $_.Exception.Message
                Write-Warning "Failed to remove assignment from '$name': $err"
            }
        }
    }
}
