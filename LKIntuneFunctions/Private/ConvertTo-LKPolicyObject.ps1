function ConvertTo-LKPolicyObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$RawPolicy,

        [Parameter(Mandatory)]
        [hashtable]$PolicyType,

        [string]$ResolvedScope
    )

    $scope = if ($ResolvedScope) { $ResolvedScope } else { $PolicyType.TargetScope }

    # For MobileApp, resolve the specific app type from @odata.type
    $displayType = if ($PolicyType.TypeName -eq 'App' -and $RawPolicy.'@odata.type') {
        Resolve-LKAppDisplayType -ODataType $RawPolicy.'@odata.type'
    } else {
        $PolicyType.DisplayName
    }

    [PSCustomObject]@{
        PSTypeName  = 'LKPolicy'
        Id          = $RawPolicy.id
        Name        = $RawPolicy.($PolicyType.NameProperty)
        PolicyType  = $PolicyType.TypeName
        DisplayType = $displayType
        Description = $RawPolicy.description
        TargetScope = $scope
        CreatedAt   = $RawPolicy.createdDateTime
        ModifiedAt  = $RawPolicy.lastModifiedDateTime
        RawObject   = $RawPolicy
    }
}
