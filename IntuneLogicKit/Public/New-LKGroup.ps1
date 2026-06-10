function New-LKGroup {
    <#
    .SYNOPSIS
        Creates a new Entra ID security group (assigned or dynamic) for Intune.
    .DESCRIPTION
        Creates a security group in Entra ID. `-GroupType` selects the assignment
        model (Assigned or Dynamic). For Dynamic groups, pass `-MembershipRule`;
        Entra infers whether it's a dynamic user or dynamic device group from the
        rule itself (`user.*` vs `device.*`).

        Dynamic groups require an Entra ID P1 license in the tenant.
    .EXAMPLE
        New-LKGroup -Name 'XW365-Intune-U-Pilot Users' -Description 'Pilot users for XW365'
        Assigned security group (the default).
    .EXAMPLE
        New-LKGroup -Name 'XW365-Intune-U-All users' -GroupType Dynamic `
            -MembershipRule '(user.accountEnabled -eq true) and (user.assignedPlans -any (assignedPlan.servicePlanId -eq "c1ec4a95-1f05-45b3-a911-aa3fa01094f5" -and assignedPlan.capabilityStatus -eq "Enabled"))'
        Dynamic user group - Entra infers "dynamic user" from the `user.*` rule.
    .EXAMPLE
        New-LKGroup -Name 'XW365-Intune-Windows-C-All Physical Devices' -GroupType Dynamic `
            -MembershipRule '(device.deviceModel -notContains "Virtual Machine") and (device.managementType -eq "MDM") and (device.deviceOSType -contains "Windows")'
        Dynamic device group - Entra infers "dynamic device" from the `device.*` rule.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description,

        [ValidateSet('Assigned', 'Dynamic')]
        [string]$GroupType = 'Assigned',

        [string]$MembershipRule,

        [ValidateSet('On', 'Paused')]
        [string]$MembershipRuleProcessingState = 'On'
    )

    Assert-LKSession -RequireWrite

    # Validate -GroupType / -MembershipRule combination
    if ($GroupType -eq 'Dynamic' -and -not $MembershipRule) {
        throw "Dynamic groups require -MembershipRule. Pass the rule, or use -GroupType Assigned (default)."
    }
    if ($GroupType -eq 'Assigned' -and $MembershipRule) {
        throw "-MembershipRule is only valid with -GroupType Dynamic."
    }

    # Check if group already exists
    try {
        $existing = Resolve-LKGroupId -GroupName $Name
        if ($existing) {
            Write-Warning "Group '$Name' already exists (Id: $existing)."
            return Get-LKGroup -Name $Name -NameMatch Exact
        }
    } catch {
        # Group not found - this is expected, proceed with creation
    }

    $mailNickname = ($Name -replace '[^a-zA-Z0-9]', '').ToLower()
    if (-not $mailNickname) { $mailNickname = 'group' }

    # Sniff the rule for display-only classification. Entra infers the real
    # resource type (user vs device) from the rule itself.
    $dynamicFlavor = if ($GroupType -eq 'Dynamic') {
        $hasUser   = $MembershipRule -match '(?i)\buser\.'
        $hasDevice = $MembershipRule -match '(?i)\bdevice\.'
        if ($hasUser -and -not $hasDevice)      { 'user' }
        elseif ($hasDevice -and -not $hasUser)  { 'device' }
        else                                     { $null }
    } else { $null }

    $typeLabel = switch ($GroupType) {
        'Assigned' { 'Assigned security group' }
        'Dynamic'  {
            if ($dynamicFlavor)     { "Dynamic $dynamicFlavor security group ($MembershipRuleProcessingState)" }
            else                    { "Dynamic security group ($MembershipRuleProcessingState)" }
        }
    }

    $summary = [ordered]@{
        Name        = $Name
        Description = if ($Description) { $Description } else { '(none)' }
        Type        = $typeLabel
    }
    if ($GroupType -eq 'Dynamic') { $summary['Rule'] = $MembershipRule }

    Write-LKActionSummary -Action 'CREATE GROUP' -Details $summary

    if ($PSCmdlet.ShouldProcess($Name, "Create $($typeLabel.ToLower())")) {
        $body = [ordered]@{
            displayName     = $Name
            mailEnabled     = $false
            mailNickname    = $mailNickname
            securityEnabled = $true
        }

        # Only send description if caller provided a non-empty value. Some tenants
        # reject an empty-string description with a generic 400 BadRequest.
        if ($Description) {
            $body.description = $Description
        }

        if ($GroupType -eq 'Dynamic') {
            $body.groupTypes                    = @('DynamicMembership')
            $body.membershipRule                = $MembershipRule
            $body.membershipRuleProcessingState = $MembershipRuleProcessingState
        } else {
            $body.groupTypes = @()
        }

        try {
            $result = Invoke-LKGraphRequest -Method POST -Uri '/groups' -ApiVersion 'v1.0' -Body $body
        } catch {
            # Surface Graph's detailed error payload when available
            $detail = $_.Exception.Message
            if ($_.ErrorDetails.Message) {
                try {
                    $parsed = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop
                    if ($parsed.error.message) {
                        $detail = $parsed.error.message
                    } else {
                        $detail = $_.ErrorDetails.Message
                    }
                } catch {
                    $detail = $_.ErrorDetails.Message
                }
            }
            throw "Failed to create group '$Name': $detail"
        }

        $resolvedMembership = if ($result.groupTypes -contains 'DynamicMembership') {
            if ($result.membershipRuleProcessingState) {
                "Dynamic ($($result.membershipRuleProcessingState))"
            } else {
                'Dynamic'
            }
        } else {
            'Assigned'
        }

        [PSCustomObject]@{
            PSTypeName     = 'LKGroup'
            Id             = $result.id
            Name           = $result.displayName
            Description    = $result.description
            GroupType      = 'Security'
            MembershipType = $resolvedMembership
            MembershipRule = $result.membershipRule
        }
    }
}
