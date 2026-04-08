$script:LKSession = @{
    Connected   = $false
    TenantId    = $null
    TenantName  = $null
    Account     = $null
    Scopes      = @()
    ConnectedAt = $null
}

$script:LKSessionPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'IntuneLogicKit\session.json'

$script:LKGitHubRepo = 'JesperNordkvist/Intune-Logic-Kit'

$script:LKFilterNameCache = @{}
$script:LKPolicyNameCache = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:LKGroupNameCache  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$script:LKRequiredScopes = @(
    'DeviceManagementConfiguration.ReadWrite.All'
    'DeviceManagementManagedDevices.ReadWrite.All'
    'DeviceManagementApps.ReadWrite.All'
    'DeviceManagementServiceConfig.ReadWrite.All'
    'DeviceManagementRBAC.ReadWrite.All'
    'Organization.Read.All'
)
