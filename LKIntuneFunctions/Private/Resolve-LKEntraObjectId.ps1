function Resolve-LKEntraObjectId {
    <#
    .SYNOPSIS
        Batch-resolves Entra Object IDs from Intune azureADDeviceId values.
    .DESCRIPTION
        Takes an array of azureADDeviceId (device registration GUIDs) and queries
        the Entra /devices endpoint to get the directory object IDs. Returns a
        hashtable mapping azureADDeviceId -> Entra Object ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$DeviceIds
    )

    $map = @{}
    # Filter out empty/null values
    $validIds = @($DeviceIds | Where-Object { $_ })
    if ($validIds.Count -eq 0) { return $map }

    # Batch in groups of 15 to stay within OData filter limits
    $batchSize = 15
    for ($i = 0; $i -lt $validIds.Count; $i += $batchSize) {
        $batch = $validIds[$i..[Math]::Min($i + $batchSize - 1, $validIds.Count - 1)]
        $filterClauses = $batch | ForEach-Object { "deviceId eq '$_'" }
        $filter = $filterClauses -join ' or '
        $uri = "/devices?`$filter=$filter&`$select=id,deviceId"

        try {
            $results = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -All
            foreach ($device in $results) {
                if ($device.deviceId) {
                    $map[$device.deviceId] = $device.id
                }
            }
        } catch {
            Write-Verbose "Failed to resolve Entra Object IDs for batch: $($_.Exception.Message)"
        }
    }

    return $map
}
