function Remove-LKGroupMember {
    <#
    .SYNOPSIS
        Removes a device or user from an Entra ID group.
    .EXAMPLE
        Remove-LKGroupMember -GroupName 'SG-Intune-TestDevices' -DeviceName 'YOURPC-001'
    .EXAMPLE
        Get-LKDevice -User "Jesper" | Remove-LKGroupMember -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Get-LKUser -Name "Jesper" | Remove-LKGroupMember -GroupName 'SG-Intune-TestUsers'
    .EXAMPLE
        Remove-LKGroupMember -GroupName 'SG-Intune-TestUsers' -UserName 'Jesper Nordkvist'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByDeviceName')]
        [Parameter(Mandatory, ParameterSetName = 'ByDeviceId')]
        [Parameter(Mandatory, ParameterSetName = 'ByUserName')]
        [Parameter(Mandatory, ParameterSetName = 'ByUserId')]
        [Parameter(Mandatory, ParameterSetName = 'ByPipeline')]
        [string]$GroupName,

        [Parameter(Mandatory, ParameterSetName = 'ByDeviceName')]
        [string]$DeviceName,

        [Parameter(Mandatory, ParameterSetName = 'ByDeviceId')]
        [string]$DeviceId,

        [Parameter(Mandatory, ParameterSetName = 'ByUserName')]
        [string]$UserName,

        [Parameter(Mandatory, ParameterSetName = 'ByUserId')]
        [string]$UserId,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject
    )

    begin {
        Assert-LKSession -RequireWrite
        $groupId = Resolve-LKGroupId -GroupName $GroupName
    }

    process {
        $resolved = Resolve-LKMemberId -InputObject $InputObject -DeviceName $DeviceName -DeviceId $DeviceId -UserName $UserName -UserId $UserId
        if (-not $resolved) { return }

        $directoryObjectId = $resolved.DirectoryObjectId
        $memberDisplayName = $resolved.DisplayName
        $memberType        = $resolved.MemberType

        Write-LKActionSummary -Action 'REMOVE GROUP MEMBER' -Details ([ordered]@{
            Member = "$memberDisplayName ($memberType)"
            Group  = $GroupName
        })

        if ($PSCmdlet.ShouldProcess("$memberDisplayName from $GroupName", 'Remove group member')) {
            try {
                Invoke-LKGraphRequest -Method DELETE -Uri "/groups/$groupId/members/$directoryObjectId/`$ref" -ApiVersion 'v1.0' | Out-Null
                [PSCustomObject]@{
                    GroupName  = $GroupName
                    GroupId    = $groupId
                    MemberName = $memberDisplayName
                    MemberId   = $directoryObjectId
                    MemberType = $memberType
                    Action     = 'MemberRemoved'
                }
            } catch {
                Write-Warning "Failed to remove member: $($_.Exception.Message)"
            }
        }
    }
}
