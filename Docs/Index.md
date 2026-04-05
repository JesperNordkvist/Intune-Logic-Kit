# LKIntuneFunctions Reference

PowerShell module for Intune administration - policy assignment management, group operations, and device lookups.

---

## Required Graph API Permissions

The following delegated scopes are requested during `New-LKSession`. An Intune Administrator role provides these permissions, but admin consent may be required in your tenant.

| Scope | Purpose |
|-------|---------|
| `DeviceManagementConfiguration.ReadWrite.All` | Read/write device configurations, compliance, and Settings Catalog policies |
| `DeviceManagementManagedDevices.ReadWrite.All` | Read/write managed devices, trigger remote actions |
| `DeviceManagementApps.ReadWrite.All` | Read/write app protection, app configuration policies, and mobile apps |
| `DeviceManagementServiceConfig.ReadWrite.All` | Read/write enrollment configurations, policy sets |
| `DeviceManagementRBAC.ReadWrite.All` | Read RBAC role assignments (used for scope tag resolution) |
| `Organization.Read.All` | Read tenant/organization display name |

---

## Session Management

| Function | Description |
|----------|-------------|
| [New-LKSession](Functions/New-LKSession.md) | Opens an interactive login and connects to Microsoft Graph |
| [Get-LKSession](Functions/Get-LKSession.md) | Returns current session info (tenant, account, scopes) |
| [Close-LKSession](Functions/Close-LKSession.md) | Disconnects from Graph and clears session state |

## Policy Operations

| Function | Description |
|----------|-------------|
| [Get-LKPolicy](Functions/Get-LKPolicy.md) | Query Intune policies across all or specific types |
| [Show-LKPolicyDetail](Functions/Show-LKPolicyDetail.md) | Display a rich formatted view of policies with all settings |
| [Get-LKPolicyAssignment](Functions/Get-LKPolicyAssignment.md) | Show assignments (includes/excludes) for policies |
| [Add-LKPolicyAssignment](Functions/Add-LKPolicyAssignment.md) | Add a group as an include assignment to policies |
| [Remove-LKPolicyAssignment](Functions/Remove-LKPolicyAssignment.md) | Remove a group include assignment from policies |
| [Add-LKPolicyExclusion](Functions/Add-LKPolicyExclusion.md) | Add a group as an exclusion to policies |
| [Remove-LKPolicyExclusion](Functions/Remove-LKPolicyExclusion.md) | Remove a group exclusion from policies |
| [Copy-LKPolicyAssignment](Functions/Copy-LKPolicyAssignment.md) | Copy assignments from a source policy to targets |
| [Test-LKPolicyAssignment](Functions/Test-LKPolicyAssignment.md) | Audit policies for scope mismatches (user policy → device group) |
| [Rename-LKPolicy](Functions/Rename-LKPolicy.md) | Rename an Intune policy |

## Group Operations

| Function | Description |
|----------|-------------|
| [Get-LKGroup](Functions/Get-LKGroup.md) | Query Entra ID groups with flexible name filtering |
| [New-LKGroup](Functions/New-LKGroup.md) | Create a new Entra ID security group |
| [Remove-LKGroup](Functions/Remove-LKGroup.md) | Delete an Entra ID group |
| [Rename-LKGroup](Functions/Rename-LKGroup.md) | Rename an existing group |
| [Get-LKGroupAssignment](Functions/Get-LKGroupAssignment.md) | Find all policies a group is assigned to (reverse lookup) |
| [Get-LKGroupMember](Functions/Get-LKGroupMember.md) | List members (devices/users) of a group |
| [Add-LKGroupMember](Functions/Add-LKGroupMember.md) | Add a device or user to a group |
| [Remove-LKGroupMember](Functions/Remove-LKGroupMember.md) | Remove a device or user from a group |

## User Operations

| Function | Description |
|----------|-------------|
| [Get-LKUser](Functions/Get-LKUser.md) | Query Entra ID users by name, UPN, or department |

## Device Operations

| Function | Description |
|----------|-------------|
| [Get-LKDevice](Functions/Get-LKDevice.md) | Query managed devices by name, user, or OS |
| [Get-LKDeviceDetail](Functions/Get-LKDeviceDetail.md) | Detailed device info (compliance, config states, storage) |
| [Invoke-LKDeviceAction](Functions/Invoke-LKDeviceAction.md) | Trigger remote actions (Sync, Restart, Wipe, etc.) |

---

## Common Parameter Patterns

All functions that accept name filters use a consistent parameter set:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Name` | `String[]` | - | One or more name patterns to match |
| `-NameMatch` | `String` | `Contains` | Match mode: `Contains`, `Exact`, `Wildcard`, `Regex` |
| `-FilterScript` | `ScriptBlock` | - | Advanced client-side filter on returned objects |

All write functions support `-WhatIf` and `-Confirm` via `SupportsShouldProcess`.

## Supported Policy Types

Used with the `-PolicyType` parameter on `Get-LKPolicy`, `Get-LKGroupAssignment`, `Add-LKPolicyExclusion`, etc.

| Value | Description | Target Scope | API Version |
|-------|-------------|-------------|-------------|
| `DeviceConfiguration` | Device Configuration Profiles | Both | v1.0 |
| `SettingsCatalog` | Settings Catalog Policies | Both | beta* |
| `CompliancePolicy` | Compliance Policies | Both | v1.0 |
| `EndpointSecurity` | Endpoint Security (Intents) | Both | beta* |
| `AppProtectionIOS` | App Protection (iOS) | User | beta* |
| `AppProtectionAndroid` | App Protection (Android) | User | beta* |
| `AppProtectionWindows` | App Protection (Windows) | User | beta* |
| `AppConfiguration` | App Configuration Policies | Both | v1.0 |
| `EnrollmentConfiguration` | Enrollment Configurations | Both | v1.0 |
| `PolicySet` | Policy Sets | Both | beta* |
| `GroupPolicyConfiguration` | Group Policy (ADMX) | Both | beta* |
| `PlatformScript` | Platform Scripts | Device | beta* |
| `Remediation` | Remediations | Device | beta* |
| `DriverUpdate` | Driver Update Profiles | Device | beta* |
| `App` | Applications | Both | v1.0 |

*\* Beta endpoints may change without notice. These policy types do not yet have stable v1.0 Graph API endpoints.*
