function Assert-LKSession {
    <#
    .SYNOPSIS
        Validates that an active in-memory session exists and the Graph context still matches.
        Called at the top of every public function except New-LKSession / Remove-LKSession.
    .PARAMETER RequireWrite
        Also require the session to allow writes. Throws when the session was opened
        with New-LKSession -ReadOnly. Used by mutating commands.
    #>
    param(
        [switch]$RequireWrite
    )

    if (-not $script:LKSession.Connected) {
        throw 'No active session. Run New-LKSession to connect.'
    }

    # Verify the live Graph context hasn't changed underneath us
    $context = Get-MgContext

    if (-not $context) {
        $script:LKSession.Connected = $false
        throw 'Graph session has expired. Run New-LKSession to reconnect.'
    }

    if ($context.TenantId -ne $script:LKSession.TenantId) {
        $script:LKSession.Connected = $false
        throw ("Tenant mismatch: Graph is now connected to $($context.TenantId) but this session " +
               "was established against $($script:LKSession.TenantName) ($($script:LKSession.TenantId)). " +
               'Run New-LKSession to re-establish.')
    }

    if ($context.Account -ne $script:LKSession.Account) {
        $script:LKSession.Connected = $false
        throw ("Account mismatch: Graph is signed in as $($context.Account) but this session " +
               "was established as $($script:LKSession.Account). Run New-LKSession to re-establish.")
    }

    if ($RequireWrite -and $script:LKSession.ReadOnly) {
        throw ('This session is read-only (connected with New-LKSession -ReadOnly). ' +
               'Reconnect with New-LKSession (without -ReadOnly) to perform write operations.')
    }
}
