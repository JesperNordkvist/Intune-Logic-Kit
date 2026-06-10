function Remove-LKGroup {
    <#
    .SYNOPSIS
        Deletes an Entra ID group.
    .EXAMPLE
        Remove-LKGroup -Name 'SG-Intune-TestDevices'
    .EXAMPLE
        Remove-LKGroup -GroupId 'abc-123'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$GroupId
    )

    Assert-LKSession -RequireWrite

    $id = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        Resolve-LKGroupId -GroupName $Name
    } else {
        $GroupId
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $displayName = $Name
    } else {
        $displayName = $GroupId
        try {
            $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$id`?`$select=displayName" -ApiVersion 'v1.0'
            $displayName = $grp.displayName
        } catch {
            Write-Verbose "Could not resolve group display name for $id`: $($_.Exception.Message)"
        }
    }

    Write-LKActionSummary -Action 'DELETE GROUP' -Details ([ordered]@{
        Group   = $displayName
        GroupId = $id
    })

    if ($PSCmdlet.ShouldProcess($displayName, 'Delete group')) {
        try {
            Invoke-LKGraphRequest -Method DELETE -Uri "/groups/$id" -ApiVersion 'v1.0' | Out-Null
            [PSCustomObject]@{
                GroupId = $id
                Name    = $displayName
                Action  = 'Deleted'
            }
        } catch {
            throw "Failed to delete group '$displayName': $($_.Exception.Message)"
        }
    }
}
