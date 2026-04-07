function Write-LKTable {
    <#
    .SYNOPSIS
        Renders a colored table to the host from a list of objects.
    .DESCRIPTION
        Calculates column widths automatically, applies color rules per column,
        and writes directly to the host. Does not emit pipeline output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [string[]]$Columns,

        [hashtable]$ColorRules = @{}
    )

    if (-not $Data -or $Data.Count -eq 0) { return }

    # Calculate column widths (header length vs max data length)
    $widths = @{}
    foreach ($col in $Columns) {
        $headerLen = $col.Length
        $maxDataLen = ($Data | ForEach-Object {
            $val = $_.$col
            if ($null -eq $val) { 0 } else { "$val".Length }
        } | Measure-Object -Maximum).Maximum
        $widths[$col] = [Math]::Max($headerLen, $maxDataLen) + 2
    }

    # Header
    $headerLine = '  '
    $underLine  = '  '
    foreach ($col in $Columns) {
        $headerLine += $col.PadRight($widths[$col])
        $underLine  += ('-' * $col.Length).PadRight($widths[$col])
    }
    Write-Host ''
    Write-Host $headerLine -ForegroundColor Cyan
    Write-Host $underLine -ForegroundColor DarkGray

    # Rows
    foreach ($row in $Data) {
        Write-Host '  ' -NoNewline
        foreach ($col in $Columns) {
            $val = if ($null -eq $row.$col) { '' } else { "$($row.$col)" }
            $padded = $val.PadRight($widths[$col])

            # Apply color rules
            $color = 'White'
            if ($ColorRules.ContainsKey($col)) {
                $ruleSet = $ColorRules[$col]
                if ($ruleSet -is [scriptblock]) {
                    $color = & $ruleSet $val $row
                } elseif ($ruleSet -is [hashtable] -and $ruleSet.ContainsKey($val)) {
                    $color = $ruleSet[$val]
                }
            }

            Write-Host $padded -ForegroundColor $color -NoNewline
        }
        Write-Host ''
    }
    Write-Host ''
}
