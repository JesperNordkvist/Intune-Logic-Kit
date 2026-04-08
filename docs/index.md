---
title: Home
layout: home
nav_order: 1
---

# Intune Logic Kit
{: .fs-9 }

A PowerShell module for managing Microsoft Intune via the Graph API.
{: .fs-6 .fw-300 }

Manage policies, assignments, groups, devices, and users from the command line with a consistent, pipeline-friendly interface.

---

## Installation

### Option 1 - Download the latest release

1. Download the latest release [here](https://github.com/JesperNordkvist/Intune-Logic-Kit/releases/latest)
2. Extract the zip to a folder of your choice
3. Import the module:

```powershell
Import-Module .\IntuneLogicKit\IntuneLogicKit.psd1
```

### Option 2 - Clone the repository

```
git clone https://github.com/JesperNordkvist/Intune-Logic-Kit.git
```

Then import the module:

```powershell
Import-Module .\Intune-Logic-Kit\IntuneLogicKit\IntuneLogicKit.psd1
```

---

The module checks for updates automatically when you run `New-LKSession`. To update in place, run `Update-LKModule`.

## Quick Start

```powershell
# Connect to your tenant
New-LKSession

# List all Settings Catalog policies
Get-LKPolicy -PolicyType SettingsCatalog

# See all assignments at a glance
Get-LKPolicyOverview

# Audit for scope mismatches
Test-LKPolicyAssignment -Detailed

# Find everything assigned to a group
Get-LKGroupAssignment -Name 'Pilot Devices' -NameMatch Exact
```

## Features

- **32 commands** covering policies, assignments, groups, devices, and users
- **16 policy types** supported including Settings Catalog, Endpoint Security, Compliance, Apps, Autopilot, and more
- **Pipeline-friendly** - all functions accept and emit objects for chaining
- **Scope-aware** - automatic detection of user/device scope mismatches
- **Policy comparison** - side-by-side setting diffs and conflict detection
- **Device comparison** - detect drift in OS, apps, and configuration across devices
- **Export** - export policies and settings to JSON or CSV
- **Tab completion** - auto-complete policy and group names after connecting
- **Safe by default** - all write operations support `-WhatIf` and `-Confirm`
- **App intent support** - Required, Available, and Uninstall for app assignments

## Requirements

| Requirement | Minimum |
|---|---|
| PowerShell | 5.1+ |
| Microsoft Graph PowerShell SDK | `Microsoft.Graph.Authentication` module |
| Permissions | Intune Administrator role (or equivalent Graph scopes) |

## Required Graph Permissions

The following delegated scopes are requested during `New-LKSession`. An Intune Administrator role provides these permissions, but admin consent may be required in your tenant.

| Scope | Purpose |
|---|---|
| `DeviceManagementConfiguration.ReadWrite.All` | Device configs, compliance, Settings Catalog |
| `DeviceManagementManagedDevices.ReadWrite.All` | Managed devices, remote actions |
| `DeviceManagementApps.ReadWrite.All` | App protection, app configuration, mobile apps |
| `DeviceManagementServiceConfig.ReadWrite.All` | Enrollment configs, policy sets |
| `DeviceManagementRBAC.ReadWrite.All` | Scope tag resolution |
| `Organization.Read.All` | Tenant display name |

## Common Parameter Patterns

All functions that accept name filters use a consistent parameter set:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Name` | `String[]` | - | One or more name patterns to match |
| `-NameMatch` | `String` | `Contains` | Match mode: `Contains`, `Exact`, `Wildcard`, `Regex` |

All write operations (Add, Remove, Copy, Rename, New, Invoke) support `-WhatIf` and `-Confirm`:

| Parameter | Effect |
|---|---|
| `-WhatIf` | Previews the action without making any changes - shows what *would* happen |
| `-Confirm` | Prompts for confirmation before each action (enabled by default on destructive operations) |
| `-Confirm:$false` | Suppresses the confirmation prompt for batch/scripted operations |

```powershell
# Preview what would be assigned without making changes
Add-LKPolicyAssignment -PolicyName "Contoso Baseline" -GroupName 'SG-Pilot' -WhatIf

# Suppress confirmation for scripted batch operations
Get-LKPolicy -Name "Contoso" | Remove-LKPolicyAssignment -GroupName 'OldGroup' -Confirm:$false
```

## Supported Policy Types

Used with the `-PolicyType` parameter across policy and assignment functions.

| Value | Description | Target Scope | API |
|---|---|---|---|
| `DeviceConfiguration` | Device Configuration Profiles | Both | v1.0 |
| `SettingsCatalog` | Settings Catalog Policies | Both | beta |
| `CompliancePolicy` | Compliance Policies | Both | v1.0 |
| `EndpointSecurity` | Endpoint Security (Intents) | Both | beta |
| `AppProtectionIOS` | App Protection (iOS) | User | beta |
| `AppProtectionAndroid` | App Protection (Android) | User | beta |
| `AppProtectionWindows` | App Protection (Windows) | User | beta |
| `AppConfiguration` | App Configuration Policies | Both | v1.0 |
| `EnrollmentConfiguration` | Enrollment Configurations | Both | v1.0 |
| `PolicySet` | Policy Sets | Both | beta |
| `GroupPolicyConfiguration` | Group Policy (ADMX) | Both | beta |
| `PlatformScript` | Platform Scripts | Device | beta |
| `Remediation` | Remediations | Device | beta |
| `DriverUpdate` | Driver Update Profiles | Device | beta |
| `App` | Applications | Both | v1.0 |
| `AutopilotDeploymentProfile` | Autopilot Deployment Profiles | Device | beta |
