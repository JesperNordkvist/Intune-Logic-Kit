$script:LKSession = @{
    Connected   = $false
    TenantId    = $null
    TenantName  = $null
    Account     = $null
    Scopes      = @()
    ReadOnly    = $false
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

# Read-only counterpart requested by New-LKSession -ReadOnly. Consents to no
# write scopes, so locked-down tenants can audit without granting ReadWrite.
$script:LKReadOnlyScopes = @(
    'DeviceManagementConfiguration.Read.All'
    'DeviceManagementManagedDevices.Read.All'
    'DeviceManagementApps.Read.All'
    'DeviceManagementServiceConfig.Read.All'
    'DeviceManagementRBAC.Read.All'
    'Organization.Read.All'
)
