$script:LKSession = @{
    Connected   = $false
    TenantId    = $null
    TenantName  = $null
    Account     = $null
    Scopes      = @()
    ConnectedAt = $null
}

$script:LKSessionPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'LKIntuneFunctions\session.json'

$script:LKGitHubRepo = 'JesperNordkvist/Lowkey-Intune-Functions'

$script:LKRequiredScopes = @(
    'DeviceManagementConfiguration.ReadWrite.All'
    'DeviceManagementManagedDevices.ReadWrite.All'
    'DeviceManagementApps.ReadWrite.All'
    'DeviceManagementServiceConfig.ReadWrite.All'
    'DeviceManagementRBAC.ReadWrite.All'
    'Organization.Read.All'
)
