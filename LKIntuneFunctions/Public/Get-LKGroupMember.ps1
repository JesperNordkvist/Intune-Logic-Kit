function Get-LKGroupMember {
    <#
    .SYNOPSIS
        Lists the members of an Entra ID group.
    .EXAMPLE
        Get-LKGroupMember -GroupName 'SG-Intune-TestDevices'
    .EXAMPLE
        Get-LKGroup -Name 'SG-Test*' -NameMatch Wildcard | Get-LKGroupMember
    .EXAMPLE
        Get-LKGroupMember -GroupName 'SG-Intune-TestDevices' -MemberType Device
    .EXAMPLE
        Get-LKGroupMember -GroupName 'SG-Intune-TestDevices' -DisplayAs Table
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$GroupName,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$GroupId,

        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [ValidateSet('All', 'Device', 'User')]
        [string]$MemberType = 'All',

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    begin {
        Assert-LKSession
        if ($DisplayAs -eq 'Table') { $collector = [System.Collections.Generic.List[object]]::new() }
    }

    process {
        $resolvedGroupId   = $null
        $resolvedGroupName = $null

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $resolvedGroupId   = Resolve-LKGroupId -GroupName $GroupName
                $resolvedGroupName = $GroupName
            }
            'ById' {
                $resolvedGroupId   = $GroupId
                $resolvedGroupName = $GroupId
                try {
                    $grp = Invoke-LKGraphRequest -Method GET -Uri "/groups/$GroupId`?`$select=displayName" -ApiVersion 'v1.0'
                    $resolvedGroupName = $grp.displayName
                } catch {
                    Write-Verbose "Could not resolve group display name for $GroupId`: $($_.Exception.Message)"
                }
            }
            'ByPipeline' {
                if (-not $InputObject) { return }
                $resolvedGroupId   = $InputObject.Id
                $resolvedGroupName = $InputObject.Name
            }
        }

        if (-not $resolvedGroupId) { return }

        try {
            $members = Invoke-LKGraphRequest -Method GET `
                -Uri "/groups/$resolvedGroupId/members?`$select=id,displayName,userPrincipalName,deviceId,operatingSystem,@odata.type" `
                -ApiVersion 'v1.0' -All
        } catch {
            Write-Warning "Failed to get members for '$resolvedGroupName': $($_.Exception.Message)"
            return
        }

        if (-not $members) { return }

        foreach ($member in $members) {
            $odataType = $member.'@odata.type'
            $type = if ($odataType -like '*device*') { 'Device' }
                    elseif ($odataType -like '*user*') { 'User' }
                    else { 'Other' }

            if ($MemberType -ne 'All' -and $type -ne $MemberType) { continue }

            $obj = [PSCustomObject]@{
                PSTypeName        = 'LKGroupMember'
                GroupName         = $resolvedGroupName
                GroupId           = $resolvedGroupId
                MemberId          = $member.id
                DisplayName       = $member.displayName
                MemberType        = $type
                UserPrincipalName = if ($type -eq 'User') { $member.userPrincipalName } else { $null }
                DeviceId          = if ($type -eq 'Device') { $member.deviceId } else { $null }
                OS                = if ($type -eq 'Device') { $member.operatingSystem } else { $null }
            }
            if ($DisplayAs -eq 'Table') { $collector.Add($obj) } else { $obj }
        }
    }

    end {
        if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
            $collector | Format-Table DisplayName, MemberType, UserPrincipalName, OS -AutoSize
        }
    }
}
