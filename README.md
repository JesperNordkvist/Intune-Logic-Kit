# LKIntuneFunctions

PowerShell module for Microsoft Intune administration via the Microsoft Graph API. Built to simplify bulk policy management, assignment auditing, and day-to-day Intune operations.

## Features

- **Policy Management** - Query, rename, and inspect policies across 15 policy types (Settings Catalog, Compliance, Endpoint Security, Platform Scripts, Apps, and more)
- **Assignment Operations** - Add, remove, and copy group assignments and exclusions across policies, with scope mismatch protection
- **Assignment Auditing** - Detect mismatched assignments (e.g., user-scoped policies assigned to device groups) across your entire tenant
- **Group Operations** - Create, rename, delete groups; manage members; reverse-lookup which policies target a group
- **Device & User Lookups** - Query devices and users, view detailed device info, trigger remote actions (Sync, Restart, Wipe)
- **Scope Resolution** - Automatically resolves policy scope (User/Device) via Graph metadata for accurate mismatch detection

## Quick Start

```powershell
# Import the module
Import-Module .\LKIntuneFunctions\LKIntuneFunctions.psd1

# Connect to your tenant
New-LKSession

# List all Settings Catalog policies
Get-LKPolicy -PolicyType SettingsCatalog

# See what's assigned to a specific group
Get-LKGroupAssignment -Name 'Pilot Devices' -NameMatch Exact

# Audit your tenant for scope mismatches
Test-LKPolicyAssignment -Detailed

# Add a group to all compliance policies
Add-LKPolicyAssignment -GroupName 'SG-Intune-AllUsers' -All -PolicyType CompliancePolicy

# View detailed settings of a policy
Get-LKPolicy -Name "Microsoft Edge" | Show-LKPolicyDetail
```

## Supported Policy Types

| `-PolicyType` Value | Description |
|---|---|
| `DeviceConfiguration` | Device Configuration Profiles |
| `SettingsCatalog` | Settings Catalog Policies |
| `CompliancePolicy` | Compliance Policies |
| `EndpointSecurity` | Endpoint Security Policies |
| `AppProtectionIOS` | App Protection (iOS) |
| `AppProtectionAndroid` | App Protection (Android) |
| `AppProtectionWindows` | App Protection (Windows) |
| `AppConfiguration` | App Configuration Policies |
| `EnrollmentConfiguration` | Enrollment Configurations |
| `PolicySet` | Policy Sets |
| `GroupPolicyConfiguration` | Group Policy (ADMX) |
| `PlatformScript` | Platform Scripts |
| `Remediation` | Remediations |
| `DriverUpdate` | Driver Update Profiles |
| `App` | Applications (Win32, VPP, Store, LOB, etc.) |

## Requirements

- PowerShell 5.1 or later
- [Microsoft.Graph.Authentication](https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication) module
- An Intune-licensed tenant with appropriate admin permissions

## Required Graph Permissions

The following delegated scopes are requested during `New-LKSession`:

| Scope | Purpose |
|---|---|
| `DeviceManagementConfiguration.ReadWrite.All` | Policies, compliance, Settings Catalog |
| `DeviceManagementManagedDevices.ReadWrite.All` | Devices, remote actions |
| `DeviceManagementApps.ReadWrite.All` | App protection, app config, mobile apps |
| `DeviceManagementServiceConfig.ReadWrite.All` | Enrollment configs, policy sets |
| `DeviceManagementRBAC.ReadWrite.All` | Scope tag resolution |
| `Organization.Read.All` | Tenant display name |

## Documentation

Full function reference and examples: [https://jespernordkvist.github.io/Lowkey-Intune-Functions/](https://jespernordkvist.github.io/Lowkey-Intune-Functions/)

## License

MIT
