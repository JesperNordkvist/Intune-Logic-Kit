---
title: Home
layout: home
nav_order: 1
---

# LKIntuneFunctions
{: .fs-9 }

A PowerShell module for managing Microsoft Intune via the Graph API.
{: .fs-6 .fw-300 }

Manage policies, assignments, groups, devices, and users from the command line with a consistent, pipeline-friendly interface.

---

## Quick Start

```powershell
# Import the module
Import-Module .\LKIntuneFunctions.psd1

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

- **26 commands** covering policies, assignments, groups, devices, and users
- **15 policy types** supported including Settings Catalog, Endpoint Security, Compliance, Apps, and more
- **Pipeline-friendly** --- all functions accept and emit objects for chaining
- **Scope-aware** --- automatic detection of user/device scope mismatches
- **Safe by default** --- all write operations support `-WhatIf` and `-Confirm`
- **App intent support** --- Required, Available, and Uninstall for app assignments

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
| `-Name` | `String[]` | --- | One or more name patterns to match |
| `-NameMatch` | `String` | `Contains` | Match mode: `Contains`, `Exact`, `Wildcard`, `Regex` |

All write operations support `-WhatIf` and `-Confirm` via `SupportsShouldProcess`.

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
