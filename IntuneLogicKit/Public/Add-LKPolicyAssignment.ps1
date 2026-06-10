function Add-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Adds an include assignment to one or more Intune policies.
        The target can be an Entra ID group, all devices, or all licensed users.
    .EXAMPLE
        Get-LKPolicy -Name "XW365 - TestConfig" | Add-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Add-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
    .EXAMPLE
        Get-LKPolicy -Name "Google Chrome" -PolicyType App | Add-LKPolicyAssignment -GroupName 'All Users' -Intent Required
        Assigns an app as Required to a group.
    .EXAMPLE
        Add-LKPolicyAssignment -PolicyName "Windows - Compliance" -NameMatch Exact -AllDevices
        Assigns a policy to the built-in All Devices target.
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
        [string[]]$SearchPolicyType,

        [ValidateSet('Required', 'Available', 'Uninstall')]
        [string]$Intent,

        [string]$FilterName,

        [ValidateSet('Include', 'Exclude')]
        [string]$FilterMode
    )

    begin {
        Assert-LKSession -RequireWrite

        if ($FilterName -and -not $FilterMode) { throw "-FilterMode is required when -FilterName is specified." }
        if ($FilterMode -and -not $FilterName) { throw "-FilterName is required when -FilterMode is specified." }

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
                $targetScope    = 'Device'
                $targetTypeName = 'allDevicesAssignmentTarget'
                $groupId        = $null
            }
            'AllLicensedUsers' {
                $targetKind     = 'AllLicensedUsers'
                $targetLabel    = 'All Licensed Users'
                $targetScope    = 'User'
                $targetTypeName = 'allLicensedUsersAssignmentTarget'
                $groupId        = $null
            }
            default {
                $targetKind     = 'Group'
                $targetLabel    = $GroupName
                $targetTypeName = 'groupAssignmentTarget'
                $groupId        = Resolve-LKGroupId -GroupName $GroupName
                $targetScope    = Resolve-LKGroupScope -GroupId $groupId
            }
        }
        $targetODataType = "#microsoft.graph.$targetTypeName"

        # The target switch to forward when ByName fans out to per-policy calls.
        $targetParam = switch ($targetKind) {
            'AllDevices'       { @{ AllDevices = $true } }
            'AllLicensedUsers' { @{ AllLicensedUsers = $true } }
            default            { @{ GroupName = $GroupName } }
        }

        $filterId = $null
        if ($FilterName) { $filterId = Resolve-LKFilterId -FilterName $FilterName }

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
                if ($FilterName) { $passThrough['FilterName'] = $FilterName; $passThrough['FilterMode'] = $FilterMode }
                Add-LKPolicyAssignment -InputObject $pol @targetParam @passThrough
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

        $alreadyIncluded = $assignments | Where-Object {
            if ($targetKind -eq 'Group') {
                $_.target.'@odata.type' -like '*groupAssignmentTarget' -and
                $_.target.'@odata.type' -notlike '*exclusion*' -and
                $_.target.groupId -eq $groupId
            } else {
                $_.target.'@odata.type' -like "*$targetTypeName"
            }
        }
        if ($alreadyIncluded) {
            Write-Verbose "Skipping '$name' - '$targetLabel' already assigned."
            return
        }

        # Scope mismatch check - skip the assignment if scopes are incompatible
        $policyScope = $typeEntry.TargetScope
        if ($InputObject -and $InputObject.TargetScope) { $policyScope = $InputObject.TargetScope }
        if ($targetScope -ne 'Unknown' -and $policyScope -ne 'Both' -and $targetScope -ne $policyScope) {
            Write-Warning "Skipping '$name': target '$targetLabel' is $targetScope-scoped, but the policy is $policyScope-scoped."
            return
        }

        $intentLabel = if ($Intent) { " ($Intent)" } else { '' }
        $filterLabel = if ($FilterName) { " [Filter: $FilterName ($FilterMode)]" } else { '' }
        Write-LKActionSummary -Action 'ADD ASSIGNMENT' -Details ([ordered]@{
            Policy = "$name ($($typeEntry.DisplayName))"
            Target = "$targetLabel (Include)$intentLabel$filterLabel"
            Scope  = "Policy=$policyScope, Target=$targetScope"
        })

        if ($PSCmdlet.ShouldProcess("$name ($($typeEntry.DisplayName))", "Add include assignment for '$targetLabel'$intentLabel$filterLabel")) {
            $newTarget = @{ '@odata.type' = $targetODataType }
            if ($targetKind -eq 'Group') {
                $newTarget['groupId'] = $groupId
            }
            if ($filterId) {
                $newTarget['deviceAndAppManagementAssignmentFilterId']   = $filterId
                $newTarget['deviceAndAppManagementAssignmentFilterType'] = $FilterMode.ToLower()
            }
            $newAssignment = @{ target = $newTarget }
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
                    GroupName  = $targetLabel
                    GroupId    = $groupId
                }
            } catch {
                $err = $_.Exception.Message
                Write-Warning "Failed to add assignment to '$name': $err"
            }
        }
    }
}
