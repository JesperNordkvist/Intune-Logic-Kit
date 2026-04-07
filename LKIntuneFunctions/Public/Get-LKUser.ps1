function Get-LKUser {
    <#
    .SYNOPSIS
        Queries Entra ID users with flexible name and department filtering.
    .EXAMPLE
        Get-LKUser -Name "Jesper" -NameMatch Contains
    .EXAMPLE
        Get-LKUser -Name "jesper@contoso.com" -NameMatch Exact
    .EXAMPLE
        Get-LKUser -Department "IT"
    .EXAMPLE
        Get-LKUser -Department "IT" -DisplayAs Table
    #>
    [CmdletBinding()]
    param(
        [string[]]$Name,

        [ValidateSet('Contains', 'Exact', 'Wildcard', 'Regex')]
        [string]$NameMatch = 'Contains',

        [string]$Department,

        [scriptblock]$FilterScript,

        [ValidateSet('List', 'Table')]
        [string]$DisplayAs = 'List'
    )

    Assert-LKSession

    if ($DisplayAs -eq 'Table') { $collector = [System.Collections.Generic.List[object]]::new() }

    $selectFields = 'id,displayName,userPrincipalName,mail,jobTitle,department,accountEnabled'
    $clientSideNameFilter = $false
    $clientSideDeptFilter = $false

    if ($Name -and $Name.Count -eq 1 -and $NameMatch -eq 'Exact') {
        $escaped = $Name[0].Replace("'", "''")
        $uri = "/users?`$filter=displayName eq '$escaped' or userPrincipalName eq '$escaped'&`$select=$selectFields"
        if ($Department) {
            $deptEscaped = $Department.Replace("'", "''")
            $uri = "/users?`$filter=(displayName eq '$escaped' or userPrincipalName eq '$escaped') and department eq '$deptEscaped'&`$select=$selectFields"
        }
    } elseif ($Name -and $Name.Count -eq 1 -and $NameMatch -eq 'Contains') {
        $escaped = $Name[0].Replace("'", "''")
        $uri = "/users?`$search=`"displayName:$escaped`"&`$select=$selectFields&`$count=true"
        if ($Department) { $clientSideDeptFilter = $true }
    } else {
        $uri = "/users?`$select=$selectFields&`$top=999"
        if ($Name) { $clientSideNameFilter = $true }
        if ($Department -and -not $clientSideNameFilter) {
            $deptEscaped = $Department.Replace("'", "''")
            $uri = "/users?`$filter=department eq '$deptEscaped'&`$select=$selectFields&`$top=999"
        } elseif ($Department) {
            $clientSideDeptFilter = $true
        }
    }

    try {
        if ($uri -like '*$search*' -or $uri -like '*$count*') {
            $users = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -Headers @{ ConsistencyLevel = 'eventual' } -All
        } else {
            $users = Invoke-LKGraphRequest -Method GET -Uri $uri -ApiVersion 'v1.0' -All
        }
    } catch {
        throw "Failed to query users: $($_.Exception.Message)"
    }

    if (-not $users) { return }

    foreach ($user in $users) {
        if ($clientSideNameFilter) {
            $nameMatch1 = Test-LKNameMatch -Value $user.displayName -Name $Name -NameMatch $NameMatch
            $nameMatch2 = Test-LKNameMatch -Value $user.userPrincipalName -Name $Name -NameMatch $NameMatch
            if (-not $nameMatch1 -and -not $nameMatch2) { continue }
        }

        if ($clientSideDeptFilter -and $user.department -ne $Department) { continue }

        $obj = [PSCustomObject]@{
            PSTypeName        = 'LKUser'
            Id                = $user.id
            DisplayName       = $user.displayName
            UserPrincipalName = $user.userPrincipalName
            Mail              = $user.mail
            JobTitle          = $user.jobTitle
            Department        = $user.department
            AccountEnabled    = $user.accountEnabled
        }

        if ($FilterScript -and -not ($obj | Where-Object $FilterScript)) {
            continue
        }

        if ($DisplayAs -eq 'Table') { $collector.Add($obj) } else { $obj }
    }

    if ($DisplayAs -eq 'Table' -and $collector.Count -gt 0) {
        $collector | Format-Table DisplayName, UserPrincipalName, Department, JobTitle -AutoSize
    }
}
