function Resolve-LKReportablePolicy {
    <#
    .SYNOPSIS
        Looks up a policy by name or ID across the policy types Export-LKReport can target
        (Remediation, PlatformScript, App).
    .DESCRIPTION
        Internal helper used by Export-LKReport to infer the report type when the user
        supplies -PolicyName or -PolicyId without -ReportType.

        - Name lookup queries Get-LKPolicy with PolicyType filtered to the reportable
          types and returns every match (caller decides what to do if there are multiple).
        - ID lookup probes each reportable endpoint in turn and returns the first match,
          or $null if none of them recognize the ID.

        Always returns LKPolicy-shaped objects (Id / Name / PolicyType) so callers can
        treat name-resolved and ID-resolved results uniformly.
    #>
    [CmdletBinding()]
    param(
        [string]$PolicyName,
        [string]$PolicyId
    )

    $reportableTypes = @('Remediation', 'PlatformScript', 'App')

    if ($PolicyName) {
        return @(Get-LKPolicy -PolicyType $reportableTypes -Name $PolicyName -NameMatch Exact)
    }

    if ($PolicyId) {
        foreach ($pTypeName in $reportableTypes) {
            $typeEntry = $script:LKPolicyTypes | Where-Object { $_.TypeName -eq $pTypeName }
            if (-not $typeEntry) { continue }

            try {
                $raw = Invoke-LKGraphRequest -Method GET `
                    -Uri "$($typeEntry.Endpoint)/$PolicyId" `
                    -ApiVersion $typeEntry.ApiVersion
            } catch {
                # 404 / not this type — try next
                continue
            }

            if ($raw -and $raw.id) {
                return ConvertTo-LKPolicyObject -RawPolicy $raw -PolicyType $typeEntry
            }
        }
        return $null
    }

    return $null
}
