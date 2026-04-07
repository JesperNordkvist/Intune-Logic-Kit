function New-LKSession {
    <#
    .SYNOPSIS
        Opens an interactive login and connects to Microsoft Graph for Intune administration.
    .DESCRIPTION
        Launches a browser-based sign-in prompt. Uses delegated auth with the built-in
        Microsoft Graph PowerShell app - no custom app registration required. The user's
        Intune Administrator role provides effective permissions.

        If a previous session was established against a different tenant or account,
        a warning is shown so you don't accidentally work in the wrong environment.
    .EXAMPLE
        New-LKSession
    #>
    [CmdletBinding()]
    param ()

    # Install the Graph auth module if missing
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host 'Microsoft.Graph.Authentication not found - installing...' -ForegroundColor Cyan
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
    }

    # Import if not already loaded
    if (-not (Get-Module Microsoft.Graph.Authentication)) {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    }

    # Delegated sign-in - opens a browser window, no app registration needed
    Connect-MgGraph -Scopes $script:LKRequiredScopes -NoWelcome -ErrorAction Stop

    $context = Get-MgContext

    # Get tenant display name via REST so we only depend on the auth module
    $orgResponse = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization'
    $org = $orgResponse.value | Select-Object -First 1

    # Warn if switching tenant or account from a previous session
    if (Test-Path $script:LKSessionPath) {
        $previous = Get-Content $script:LKSessionPath -Raw | ConvertFrom-Json
        if ($previous.TenantId -and $previous.TenantId -ne $context.TenantId) {
            Write-Warning "Tenant changed: was '$($previous.TenantName)' -> now '$($org.displayName)'."
        }
        if ($previous.Account -and $previous.Account -ne $context.Account) {
            Write-Warning "Account changed: was $($previous.Account) -> now $($context.Account)."
        }
    }

    # Validate that all required scopes were granted
    $grantedScopes = $context.Scopes
    $missingScopes = @($script:LKRequiredScopes | Where-Object { $_ -notin $grantedScopes })
    if ($missingScopes.Count -gt 0) {
        Write-Warning "The following scopes were not granted (admin consent may be required):"
        $missingScopes | ForEach-Object { Write-Warning "  - $_" }
        Write-Warning 'Some operations may fail. Ask your admin to grant consent or re-run New-LKSession.'
    }

    $script:LKSession = @{
        Connected   = $true
        TenantId    = $context.TenantId
        TenantName  = $org.displayName
        Account     = $context.Account
        Scopes      = $grantedScopes
        ConnectedAt = [datetime]::Now
    }

    # Persist session reference for the tenant/account guardrail
    $sessionDir = Split-Path $script:LKSessionPath -Parent
    if (-not (Test-Path $sessionDir)) {
        New-Item -Path $sessionDir -ItemType Directory -Force | Out-Null
    }

    @{
        TenantId    = $script:LKSession.TenantId
        TenantName  = $script:LKSession.TenantName
        Account     = $script:LKSession.Account
        ConnectedAt = $script:LKSession.ConnectedAt.ToString('o')
    } | ConvertTo-Json | Set-Content $script:LKSessionPath -Force

    [PSCustomObject]@{
        TenantName  = $script:LKSession.TenantName
        TenantId    = $script:LKSession.TenantId
        Account     = $script:LKSession.Account
        ConnectedAt = $script:LKSession.ConnectedAt
    }

    # Non-blocking check for newer releases
    Test-LKModuleVersion
}
