function Rename-LKGroup {
    <#
    .SYNOPSIS
        Renames an existing Entra ID group.
    .EXAMPLE
        Rename-LKGroup -Name 'SG-Old-Name' -NewName 'SG-New-Name'
    .EXAMPLE
        Rename-LKGroup -GroupId 'abc-123' -NewName 'SG-New-Name'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$GroupId,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    Assert-LKSession -RequireWrite

    $id = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        Resolve-LKGroupId -GroupName $Name
    } else {
        $GroupId
    }

    $displayName = if ($Name) { $Name } else { $GroupId }

    Write-LKActionSummary -Action 'RENAME GROUP' -Details ([ordered]@{
        Current = $displayName
        New     = $NewName
    })

    if ($PSCmdlet.ShouldProcess($displayName, "Rename to '$NewName'")) {
        $body = @{ displayName = $NewName }

        try {
            Invoke-LKGraphRequest -Method PATCH -Uri "/groups/$id" -ApiVersion 'v1.0' -Body $body | Out-Null
            [PSCustomObject]@{
                GroupId  = $id
                OldName  = $displayName
                NewName  = $NewName
                Action   = 'Renamed'
            }
        } catch {
            throw "Failed to rename group: $($_.Exception.Message)"
        }
    }
}
