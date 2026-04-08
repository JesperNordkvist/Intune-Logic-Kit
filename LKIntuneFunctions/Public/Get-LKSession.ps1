function Get-LKSession {
    <#
    .SYNOPSIS
        Returns the current Intune Logic Kit session info.
    .DESCRIPTION
        Shows the tenant, account, and connection details for the active session.
        Attempts to restore a previous session if the Graph token cache is still valid.
    .EXAMPLE
        Get-LKSession
    #>
    [CmdletBinding()]
    param ()

    if (-not $script:LKSession.Connected) {
        try {
            Assert-LKSession
        } catch {
            Write-Warning $_.Exception.Message
            return
        }
    }

    [PSCustomObject]@{
        TenantName  = $script:LKSession.TenantName
        TenantId    = $script:LKSession.TenantId
        Account     = $script:LKSession.Account
        Scopes      = $script:LKSession.Scopes
        ConnectedAt = $script:LKSession.ConnectedAt
    }
}
