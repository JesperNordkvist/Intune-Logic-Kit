function Copy-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Copies a group's policy assignments to another group.
    .DESCRIPTION
        Finds all policies where the source group is assigned, then assigns the target
        group to those same policies. Optionally filters by policy type. Skips policies
        where the target group is already assigned.

        By default only explicit group assignments (Include/Exclude) are copied.
        Broad targets (All Devices, All Users) are not copied as they are tenant-wide.
    .EXAMPLE
        Copy-LKPolicyAssignment -SourceGroup "XW365-Intune-D-Pilot Devices" -TargetGroup "XW365-Intune-D-Autopilot Pilot Devices"
    .EXAMPLE
        Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Production Devices" -PolicyType SettingsCatalog, CompliancePolicy
    .EXAMPLE
        Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Production Devices" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$SourceGroup,

        [Parameter(Mandatory)]
        [string]$TargetGroup,

        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string[]]$PolicyType,

        [ValidateSet('Include', 'Exclude', 'All')]
        [string]$AssignmentType = 'Include'
    )

    Assert-LKSession

    # Resolve target group upfront so we fail fast if it doesn't exist
    $targetGroupId = Resolve-LKGroupId -GroupName $TargetGroup

    # Find all policies where the source group is assigned
    $scanParams = @{ Name = $SourceGroup; NameMatch = 'Exact'; AssignmentType = $AssignmentType }
    if ($PolicyType) { $scanParams['PolicyType'] = $PolicyType }
    $scanParams['SkipScopeResolution'] = $true

    Write-Host "  Scanning policies assigned to '$SourceGroup'..." -ForegroundColor Cyan
    $assignments = @(Get-LKGroupAssignment @scanParams | Where-Object {
        $_.AssignmentType -in @('Include', 'Exclude')
    })

    if ($assignments.Count -eq 0) {
        Write-Warning "No explicit assignments found for '$SourceGroup'."
        return
    }

    Write-Host "  Found $($assignments.Count) assignment(s) across $($assignments | Select-Object -Property PolicyId -Unique | Measure-Object | Select-Object -ExpandProperty Count) policies." -ForegroundColor Cyan
    Write-Host ''

    $copied = 0
    $skipped = 0

    foreach ($assignment in $assignments) {
        $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $assignment.PolicyType }
        if (-not $typeEntry) {
            Write-Warning "Could not resolve policy type '$($assignment.PolicyType)' for '$($assignment.PolicyName)'."
            continue
        }

        # Check if target group is already assigned to this policy
        try {
            $existingAssignments = @(Get-LKRawAssignment -PolicyId $assignment.PolicyId -PolicyType $typeEntry)
        } catch {
            Write-Warning "Failed to read assignments from '$($assignment.PolicyName)': $($_.Exception.Message)"
            continue
        }

        $alreadyAssigned = $existingAssignments | Where-Object {
            $_.target.groupId -eq $targetGroupId
        }
        if ($alreadyAssigned) {
            Write-Verbose "Skipping '$($assignment.PolicyName)' - '$TargetGroup' already assigned."
            $skipped++
            continue
        }

        # Build the new assignment matching the source assignment type
        $odataType = if ($assignment.AssignmentType -eq 'Exclude') {
            '#microsoft.graph.exclusionGroupAssignmentTarget'
        } else {
            '#microsoft.graph.groupAssignmentTarget'
        }

        $newAssignment = @{
            target = @{
                '@odata.type' = $odataType
                groupId       = $targetGroupId
            }
        }

        # Carry over intent for app assignments
        if ($assignment.Intent) {
            $newAssignment['intent'] = $assignment.Intent
        }

        $intentLabel = if ($assignment.Intent) { " ($($assignment.Intent))" } else { '' }
        Write-LKActionSummary -Action 'COPY ASSIGNMENT' -Details ([ordered]@{
            Policy = "$($assignment.PolicyName) ($($assignment.DisplayType))"
            Source = "$SourceGroup ($($assignment.AssignmentType))$intentLabel"
            Target = "$TargetGroup ($($assignment.AssignmentType))$intentLabel"
        })

        if ($PSCmdlet.ShouldProcess("$($assignment.PolicyName) ($($assignment.DisplayType))", "Assign '$TargetGroup' ($($assignment.AssignmentType))$intentLabel")) {
            $updatedAssignments = @($existingAssignments) + @($newAssignment)

            try {
                Set-LKRawAssignment -PolicyId $assignment.PolicyId -PolicyType $typeEntry -Assignments $updatedAssignments
                [PSCustomObject]@{
                    PolicyName     = $assignment.PolicyName
                    PolicyType     = $assignment.PolicyType
                    DisplayType    = $assignment.DisplayType
                    AssignmentType = $assignment.AssignmentType
                    Intent         = $assignment.Intent
                    SourceGroup    = $SourceGroup
                    TargetGroup    = $TargetGroup
                    Action         = 'AssignmentCopied'
                }
                $copied++
            } catch {
                Write-Warning "Failed to assign '$TargetGroup' to '$($assignment.PolicyName)': $($_.Exception.Message)"
            }
        }
    }

    if ($copied -gt 0 -or $skipped -gt 0) {
        Write-Host ''
        Write-Host "  Done: $copied copied, $skipped skipped (already assigned)." -ForegroundColor Green
    }
}
