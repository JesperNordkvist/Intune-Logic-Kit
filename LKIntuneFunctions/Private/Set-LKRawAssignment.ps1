function Set-LKRawAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PolicyId,

        [Parameter(Mandatory)]
        [hashtable]$PolicyType,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Assignments
    )

    if ($PolicyType.AssignmentMethod -eq 'GroupAssignments') {
        # Scripts use the /assign action with BOTH assignment array formats
        $assignPath = "$($PolicyType.Endpoint)/$PolicyId/assign"
        $groupAssignments = @($Assignments | ForEach-Object {
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementScriptGroupAssignment'
                id            = "$PolicyId`_$($_.target.groupId)"
                targetGroupId = $_.target.groupId
            }
        })
        $scriptAssignments = @($Assignments | ForEach-Object {
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementScriptAssignment'
                id            = "$PolicyId`_$($_.target.groupId)"
                target        = @{
                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                    groupId       = $_.target.groupId
                }
            }
        })
        $body = @{
            deviceManagementScriptGroupAssignments = $groupAssignments
            deviceManagementScriptAssignments      = $scriptAssignments
        }
        Invoke-LKGraphRequest -Method POST -Uri $assignPath -ApiVersion $PolicyType.ApiVersion -Body $body | Out-Null
        return
    }

    # Standard assignment method: POST to /assign with full replacement
    $assignPath = "$($PolicyType.Endpoint)/$PolicyId/assign"
    $body = @{ assignments = $Assignments }

    Invoke-LKGraphRequest -Method POST -Uri $assignPath -ApiVersion $PolicyType.ApiVersion -Body $body | Out-Null
}
