function Copy-LKPolicyAssignment {
    <#
    .SYNOPSIS
        Copies all assignments from a source policy to one or more target policies.
    .EXAMPLE
        $source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
        Get-LKPolicy -Name "XW365*" -NameMatch Wildcard | Copy-LKPolicyAssignment -SourcePolicy $source
    .EXAMPLE
        $source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
        Copy-LKPolicyAssignment -SourcePolicy $source -TargetPolicyId 'def-456' -TargetPolicyType CompliancePolicy
    .EXAMPLE
        $source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
        Get-LKPolicy -Name "XW365*" | Copy-LKPolicyAssignment -SourcePolicy $source -Mode Merge
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPipeline')]
        [Parameter(Mandatory, ParameterSetName = 'ByTargetId')]
        [PSCustomObject]$SourcePolicy,

        [Parameter(Mandatory, ParameterSetName = 'BySourceId')]
        [string]$SourcePolicyId,

        [Parameter(Mandatory, ParameterSetName = 'BySourceId')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string]$SourcePolicyType,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ByTargetId')]
        [Parameter(Mandatory, ParameterSetName = 'BySourceId')]
        [string]$TargetPolicyId,

        [Parameter(Mandatory, ParameterSetName = 'ByTargetId')]
        [Parameter(Mandatory, ParameterSetName = 'BySourceId')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string]$TargetPolicyType,

        [ValidateSet('Replace', 'Merge')]
        [string]$Mode = 'Replace'
    )

    begin {
        Assert-LKSession

        if ($SourcePolicy) {
            $srcId   = $SourcePolicy.Id
            $srcType = $SourcePolicy.PolicyType
            $srcName = $SourcePolicy.Name
        } else {
            $srcId   = $SourcePolicyId
            $srcType = $SourcePolicyType
            $srcName = $SourcePolicyId
        }

        $srcTypeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $srcType }
        if (-not $srcTypeEntry) {
            throw "Unknown source policy type: $srcType"
        }

        try {
            $sourceAssignments = @(Get-LKRawAssignment -PolicyId $srcId -PolicyType $srcTypeEntry)
        } catch {
            throw "Failed to read source assignments from '$srcName': $($_.Exception.Message)"
        }

        if ($sourceAssignments.Count -eq 0) {
            Write-Warning "Source policy '$srcName' has no assignments. Nothing to copy."
        }
    }

    process {
        if ($sourceAssignments.Count -eq 0) { return }

        if ($InputObject) {
            $tgtId   = $InputObject.Id
            $tgtType = $InputObject.PolicyType
            $tgtName = $InputObject.Name
        } else {
            $tgtId   = $TargetPolicyId
            $tgtType = $TargetPolicyType
            $tgtName = $TargetPolicyId
        }

        $tgtTypeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $tgtType }
        if (-not $tgtTypeEntry) {
            Write-Warning "Unknown target policy type: $tgtType"
            return
        }

        if ($srcId -eq $tgtId -and $srcType -eq $tgtType) {
            Write-Warning "Skipping '$tgtName' - same as source policy."
            return
        }

        if ($srcTypeEntry.AssignmentMethod -ne $tgtTypeEntry.AssignmentMethod) {
            Write-Warning "Cannot copy from '$srcName' ($($srcTypeEntry.AssignmentMethod)) to '$tgtName' ($($tgtTypeEntry.AssignmentMethod)) - incompatible assignment methods."
            return
        }

        $assignmentsToWrite = $sourceAssignments

        if ($Mode -eq 'Merge') {
            try {
                $existingTarget = @(Get-LKRawAssignment -PolicyId $tgtId -PolicyType $tgtTypeEntry)
            } catch {
                Write-Warning "Failed to read existing assignments from '$tgtName': $($_.Exception.Message)"
                return
            }

            $merged = [System.Collections.ArrayList]@($existingTarget)
            foreach ($srcAssignment in $sourceAssignments) {
                $srcGroupId   = $srcAssignment.target.groupId
                $srcOdataType = $srcAssignment.target.'@odata.type'

                $isDuplicate = $existingTarget | Where-Object {
                    $_.target.groupId -eq $srcGroupId -and
                    $_.target.'@odata.type' -eq $srcOdataType
                }

                if (-not $isDuplicate) {
                    $merged.Add($srcAssignment) | Out-Null
                }
            }
            $assignmentsToWrite = @($merged)
        }

        Write-LKActionSummary -Action 'COPY ASSIGNMENTS' -Details ([ordered]@{
            Source      = "$srcName ($($srcTypeEntry.DisplayName))"
            Target      = "$tgtName ($($tgtTypeEntry.DisplayName))"
            Assignments = "$($sourceAssignments.Count) assignment(s)"
            Mode        = $Mode
        })

        if ($PSCmdlet.ShouldProcess("$tgtName ($($tgtTypeEntry.DisplayName))", "Copy $($sourceAssignments.Count) assignment(s) from '$srcName' ($Mode mode)")) {
            try {
                Set-LKRawAssignment -PolicyId $tgtId -PolicyType $tgtTypeEntry -Assignments $assignmentsToWrite
                [PSCustomObject]@{
                    SourcePolicy      = $srcName
                    TargetPolicy      = $tgtName
                    AssignmentsCopied = $sourceAssignments.Count
                    Mode              = $Mode
                    Action            = 'AssignmentsCopied'
                }
            } catch {
                Write-Warning "Failed to write assignments to '$tgtName': $($_.Exception.Message)"
            }
        }
    }
}
