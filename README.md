# Intune Logic Kit

PowerShell module for Microsoft Intune administration via the Microsoft Graph API. Built to simplify bulk policy management, assignment auditing, and day-to-day Intune operations.

## Features

- **Policy Management** - Query, rename, and inspect policies across 16 policy types (Settings Catalog, Compliance, Endpoint Security, Platform Scripts, Apps, and more)
- **Assignment Operations** - Add, remove, and copy group assignments and exclusions across policies, with scope mismatch protection
- **Assignment Auditing** - Detect mismatched assignments (e.g., user-scoped policies assigned to device groups) across your entire tenant
- **Group Operations** - Create, rename, delete groups; manage members; reverse-lookup which policies target a group
- **Device & User Lookups** - Query devices and users, view detailed device info, trigger remote actions (Sync, Restart, Wipe)
- **Setting Search** - Search across all policy types to find which policies configure a specific setting
- **Policy Comparison** - Compare settings side by side across policies to identify configuration drift
- **Device Comparison** - Compare devices to detect drift in OS versions, installed apps, and configurations
- **Conflict Detection** - Detect policies with overlapping settings assigned to the same groups
- **Export** - Export policies and settings to JSON or CSV for documentation, auditing, or migration
- **Report Export** - Download Intune reports (devices, compliance, proactive remediations, platform scripts, app install status, malware, firewall) straight to CSV — equivalent to the portal's Export button
- **Tab Completion** - Auto-complete policy and group names across all commands after initial connection
- **Scope Resolution** - Automatically resolves policy scope (User/Device) via Graph metadata for accurate mismatch detection

## Quick Start

```powershell
# Import the module
Import-Module .\IntuneLogicKit\IntuneLogicKit.psd1

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
| `AutopilotDeploymentProfile` | Autopilot Deployment Profiles |

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

## Planned Features

All planned features for v0.4.0 have been implemented.

## Documentation

Full function reference and examples: [https://jespernordkvist.github.io/Intune-Logic-Kit/](https://jespernordkvist.github.io/Intune-Logic-Kit/)

## License

MIT
