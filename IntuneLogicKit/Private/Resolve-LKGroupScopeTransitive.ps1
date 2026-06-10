function Resolve-LKGroupScopeTransitive {
    <#
    .SYNOPSIS
        Determines group scope (User/Device/Both) by checking transitive membership.
        Unlike Resolve-LKGroupScope which samples 5 direct members, this follows
        nested groups via the /transitiveMembers endpoint for accurate deep inspection.
    .DESCRIPTION
        For dynamic groups, parses the membershipRule for a fast result.
        For assigned/static groups, queries transitive members and counts
        user vs device objects to determine scope.
        Returns a hashtable with Scope, DeviceCount, and UserCount.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    $result = @{ Scope = 'Unknown'; DeviceCount = 0; UserCount = 0 }

    # Fetch group details for dynamic rule fast-path
    try {
        $group = Invoke-LKGraphRequest -Method GET `
            -Uri "/groups/$GroupId`?`$select=displayName,membershipRule,membershipRuleProcessingState,groupTypes" `
            -ApiVersion 'v1.0'
    } catch {
        Write-Verbose "Resolve-LKGroupScopeTransitive: failed to fetch group $GroupId`: $($_.Exception.Message)"
        return $result
    }

    # Dynamic group: parse the membership rule (fast path, no member enumeration needed)
    if ($group.membershipRuleProcessingState -eq 'On' -and $group.membershipRule) {
        $rule = $group.membershipRule
        if ($rule -match '\(device\.') {
            $result.Scope = 'Device'
            return $result
        }
        if ($rule -match '\(user\.') {
            $result.Scope = 'User'
            return $result
        }
        # Rule doesn't clearly indicate scope - fall through to member check
    }

    # Assigned/unclear group: enumerate transitive members
    # Use $top=999 and $select to minimize payload; $count for totals
    $deviceCount = 0
    $userCount = 0

    try {
        $uri = "/groups/$GroupId/transitiveMembers?`$select=id&`$top=999"
        $response = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0'

        $members = $response.value
        while ($true) {
            if ($members) {
                foreach ($member in $members) {
                    $odataType = $member.'@odata.type'
                    if ($odataType -like '*device*') { $deviceCount++ }
                    elseif ($odataType -like '*user*') { $userCount++ }
                    # Skip #microsoft.graph.group - transitive already flattens nested groups
                }
            }

            # Follow pagination
            if ($response.'@odata.nextLink') {
                $nextUri = $response.'@odata.nextLink'
                # Invoke-LKGraphRequest expects a relative URI, but nextLink is absolute
                # Use Invoke-MgGraphRequest directly for pagination
                $response = Invoke-LKGraphWithRetry -Params @{
                    Method    = 'GET'
                    Uri       = $nextUri
                    ErrorAction = 'Stop'
                }
                $members = $response.value
            } else {
                break
            }
        }
    } catch {
        Write-Verbose "Resolve-LKGroupScopeTransitive: failed to enumerate transitive members for $GroupId`: $($_.Exception.Message)"
        return $result
    }

    $result.DeviceCount = $deviceCount
    $result.UserCount = $userCount

    if ($deviceCount -gt 0 -and $userCount -gt 0) {
        $result.Scope = 'Both'
    } elseif ($deviceCount -gt 0) {
        $result.Scope = 'Device'
    } elseif ($userCount -gt 0) {
        $result.Scope = 'User'
    }
    # else stays 'Unknown' (empty group)

    return $result
}
