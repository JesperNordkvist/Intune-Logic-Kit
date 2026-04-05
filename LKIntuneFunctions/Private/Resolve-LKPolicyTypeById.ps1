function Resolve-LKPolicyTypeById {
    <#
    .SYNOPSIS
        Determines the policy type for a given policy ID by probing each endpoint.
        Returns the matching PolicyType registry entry and the raw policy object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PolicyId
    )

    foreach ($type in $script:LKPolicyTypes) {
        try {
            $raw = Invoke-LKGraphRequest -Method GET `
                -Uri "$($type.Endpoint)/$PolicyId" `
                -ApiVersion $type.ApiVersion
            if ($raw) {
                return @{
                    TypeEntry = $type
                    RawPolicy = $raw
                    PolicyName = $raw.($type.NameProperty)
                }
            }
        } catch {
            # 404 or other error — not this type, try next
            continue
        }
    }

    throw "Policy ID '$PolicyId' not found in any known policy type."
}
