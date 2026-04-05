function Rename-LKPolicy {
    <#
    .SYNOPSIS
        Renames an Intune policy.
    .EXAMPLE
        Get-LKPolicy -Name "Old Policy Name" -NameMatch Exact | Rename-LKPolicy -NewName "New Policy Name"
    .EXAMPLE
        Rename-LKPolicy -PolicyId 'abc-123' -PolicyType SettingsCatalog -NewName "New Name"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$PolicyId,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateSet(
            'DeviceConfiguration', 'SettingsCatalog', 'CompliancePolicy', 'EndpointSecurity',
            'AppProtectionIOS', 'AppProtectionAndroid', 'AppProtectionWindows',
            'AppConfiguration', 'EnrollmentConfiguration', 'PolicySet',
            'GroupPolicyConfiguration', 'PlatformScript', 'Remediation',
            'DriverUpdate', 'App'
        )]
        [string]$PolicyType,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    begin {
        Assert-LKSession
    }

    process {
        if ($InputObject) {
            $id   = $InputObject.Id
            $type = $InputObject.PolicyType
            $name = $InputObject.Name
        } else {
            $id   = $PolicyId
            $type = $PolicyType
            $name = $PolicyId
        }

        $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $type }
        if (-not $typeEntry) {
            Write-Warning "Unknown policy type: $type"
            return
        }

        Write-LKActionSummary -Action 'RENAME POLICY' -Details ([ordered]@{
            Current = "$name ($($typeEntry.DisplayName))"
            New     = $NewName
        })

        if ($PSCmdlet.ShouldProcess("$name ($($typeEntry.DisplayName))", "Rename to '$NewName'")) {
            $body = @{ $typeEntry.NameProperty = $NewName }

            try {
                Invoke-LKGraphRequest -Method PATCH -Uri "$($typeEntry.Endpoint)/$id" -ApiVersion $typeEntry.ApiVersion -Body $body | Out-Null
                [PSCustomObject]@{
                    PolicyId   = $id
                    PolicyType = $typeEntry.TypeName
                    OldName    = $name
                    NewName    = $NewName
                    Action     = 'Renamed'
                }
            } catch {
                $err = $_.Exception.Message
                Write-Warning "Failed to rename '$name': $err"
            }
        }
    }
}
