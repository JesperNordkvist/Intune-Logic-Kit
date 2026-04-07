function Resolve-LKGroupScope {
    <#
    .SYNOPSIS
        Determines whether a group contains users, devices, or both.
        Checks dynamic membership rule first, then samples members for assigned groups.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    # Fetch group details
    try {
        $group = Invoke-LKGraphRequest -Method GET `
            -Uri "/groups/$GroupId`?`$select=displayName,membershipRule,membershipRuleProcessingState,groupTypes" `
            -ApiVersion 'v1.0'
    } catch {
        return 'Unknown'
    }

    # Dynamic group: parse the membership rule
    if ($group.membershipRuleProcessingState -eq 'On' -and $group.membershipRule) {
        $rule = $group.membershipRule
        if ($rule -match '\(device\.') { return 'Device' }
        if ($rule -match '\(user\.')   { return 'User' }
        return 'Unknown'
    }

    # Assigned group: check the first few members
    try {
        $response = Invoke-LKGraphRequest -Method GET `
            -Uri "/groups/$GroupId/members?`$top=5&`$select=id,@odata.type" `
            -ApiVersion 'v1.0'
        $members = $response.value
    } catch {
        return 'Unknown'
    }

    if (-not $members -or $members.Count -eq 0) { return 'Unknown' }

    $hasDevices = $false
    $hasUsers   = $false
    foreach ($member in $members) {
        $odataType = $member.'@odata.type'
        if ($odataType -like '*device*') { $hasDevices = $true }
        if ($odataType -like '*user*')   { $hasUsers = $true }
    }

    if ($hasDevices -and $hasUsers) { return 'Both' }
    if ($hasDevices) { return 'Device' }
    if ($hasUsers)   { return 'User' }

    # Fallback: infer scope from group naming convention
    $groupName = $group.displayName
    if ($groupName) {
        if ($groupName -match '[-–]\s*U\s*[-–]') { return 'User' }
        if ($groupName -match '[-–]\s*[DC]\s*[-–]') { return 'Device' }
    }

    return 'Unknown'
}
