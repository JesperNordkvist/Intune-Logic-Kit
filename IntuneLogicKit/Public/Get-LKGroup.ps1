function Get-LKGroup {
    <#
    .SYNOPSIS
        Queries Entra ID groups with flexible name filtering.
    .EXAMPLE
        Get-LKGroup -Name "SG-Windows-*" -NameMatch Wildcard
    .EXAMPLE
        Get-LKGroup -Name "TestGroup" -NameMatch Exact
    .EXAMPLE
        Get-LKGroup -Name "SG-Intune" -DisplayAs Table
    #>
    [CmdletBinding()]
    param(
        [string[]]$Name,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [scriptblock]$FilterScript,

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    Assert-LKSession

    if ($DisplayAs -eq 'Table') { $collector = [System.Collections.Generic.List[object]]::new() }

    $selectFields = 'id,displayName,description,groupTypes,membershipRule,membershipRuleProcessingState'
    $clientSideFilter = $false

    # Build the most efficient query based on match type
    if ($Name -and $Name.Count -eq 1 -and $NameMatch -eq 'Exact') {
        $escaped = $Name[0].Replace("'", "''")
        $uri = "/groups?`$filter=displayName eq '$escaped'&`$select=$selectFields"
    } elseif ($Name -and $Name.Count -eq 1 -and $NameMatch -eq 'Contains') {
        $escaped = $Name[0].Replace("'", "''")
        $uri = "/groups?`$search=`"displayName:$escaped`"&`$select=$selectFields&`$count=true"
    } else {
        $uri = "/groups?`$select=$selectFields&`$top=999"
        if ($Name) { $clientSideFilter = $true }
    }

    try {
        if ($uri -like '*$search*' -or $uri -like '*$count*') {
            $groups = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -Headers @{ ConsistencyLevel = 'eventual' } -All
        } else {
            $groups = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -All
        }
    } catch {
        throw "Failed to query groups: $($_.Exception.Message)"
    }

    if (-not $groups) { return }

    foreach ($group in $groups) {
        if ($clientSideFilter -and -not (Test-LKNameMatch -Value $group.displayName -Name $Name -NameMatch $NameMatch)) {
            continue
        }

        $membershipType = if ($group.membershipRuleProcessingState -eq 'On') { 'Dynamic' } else { 'Assigned' }
        $groupType = if ($group.groupTypes -contains 'Unified') { 'Microsoft365' } else { 'Security' }

        $obj = [PSCustomObject]@{
            PSTypeName     = 'LKGroup'
            Id             = $group.id
            Name           = $group.displayName
            Description    = $group.description
            GroupType      = $groupType
            MembershipType = $membershipType
            MembershipRule = $group.membershipRule
        }
        if ($obj.Name) { $script:LKGroupNameCache.Add($obj.Name) | Out-Null }

        if ($FilterScript -and -not ($obj | Where-Object $FilterScript)) {
            continue
        }

        if ($DisplayAs -eq 'Table') { $collector.Add($obj) } else { $obj }
    }

    if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
        $collector | Format-Table Name, GroupType, MembershipType, Description -AutoSize
    }
}
