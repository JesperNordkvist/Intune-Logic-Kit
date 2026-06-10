function Add-LKGroupMember {
    <#
    .SYNOPSIS
        Adds a device or user to an Entra ID group.
    .EXAMPLE
        Get-LKDevice -User "Jesper" | Add-LKGroupMember -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Add-LKGroupMember -GroupName 'SG-Intune-TestDevices' -DeviceName 'YOURPC-001'
    .EXAMPLE
        Get-LKUser -Name "Jesper" | Add-LKGroupMember -GroupName 'SG-Intune-TestUsers'
    .EXAMPLE
        Add-LKGroupMember -GroupName 'SG-Intune-TestUsers' -UserName 'Jesper Nordkvist'
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

        Write-LKActionSummary -Action 'ADD GROUP MEMBER' -Details ([ordered]@{
            Member = "$memberDisplayName ($memberType)"
            Group  = $GroupName
        })

        if ($PSCmdlet.ShouldProcess("$memberDisplayName -> $GroupName", 'Add group member')) {
            $body = @{
                '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$directoryObjectId"
            }

            try {
                Invoke-LKGraphRequest -Method POST -Uri "/groups/$groupId/members/`$ref" -ApiVersion 'v1.0' -Body $body | Out-Null
                [PSCustomObject]@{
                    GroupName  = $GroupName
                    GroupId    = $groupId
                    MemberName = $memberDisplayName
                    MemberId   = $directoryObjectId
                    MemberType = $memberType
                    Action     = 'MemberAdded'
                }
            } catch {
                if ($_.Exception.Message -like '*already exist*') {
                    Write-Warning "'$memberDisplayName' is already a member of '$GroupName'."
                } else {
                    Write-Warning "Failed to add member: $($_.Exception.Message)"
                }
            }
        }
    }
}
