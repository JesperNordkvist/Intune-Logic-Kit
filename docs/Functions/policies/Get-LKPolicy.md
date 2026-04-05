---
title: Get-LKPolicy
nav_order: 12
---

# Get-LKPolicy

Queries Intune policies across all or specific policy types with flexible name filtering.

## Syntax

```text
Get-LKPolicy
    [-Name <String[]>]
    [-NameMatch <String>]
    [-PolicyType <String[]>]
    [-ResolveScope]
    [-IncludeSettings]
    [-FilterScript <ScriptBlock>]
    [<CommonParameters>]
```

## Description

Searches across all 15 policy types (or a filtered subset) and returns unified policy objects. Supports flexible name matching, scope resolution, and optional settings retrieval.

## Parameters

### -Name

One or more name patterns to match against policy names.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

### -NameMatch

How `-Name` is matched. Default: `Contains`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -PolicyType

Restrict the search to specific policy types. When omitted, all types are searched.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -ResolveScope

Resolves the effective User/Device scope for each policy via Graph metadata instead of using the static registry default.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -IncludeSettings

Attaches the configured settings to each returned policy object as a `Settings` property.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -FilterScript

A script block for advanced client-side filtering on the returned objects.

| Attribute | Value |
|---|---|
| Type | `ScriptBlock` |

## Outputs

| Property | Type | Description |
|---|---|---|
| Id | String | Graph object ID |
| Name | String | Policy display name |
| Description | String | Policy description |
| PolicyType | String | Normalised type key |
| DisplayType | String | Human-readable type label |
| TargetScope | String | Device, User, or Both |
| CreatedAt | DateTime | Creation timestamp |
| ModifiedAt | DateTime | Last modification timestamp |
| RawObject | Object | Full Graph API response |
| Settings | Array | (Only with -IncludeSettings) Array of setting objects |

## Examples

### Example 1 - Search by name

```powershell
Get-LKPolicy -Name "Contoso" -NameMatch Contains
```

### Example 2 - Filter by type

```powershell
Get-LKPolicy -PolicyType SettingsCatalog, CompliancePolicy
```

### Example 3 - Wildcard with scope filter

```powershell
Get-LKPolicy -Name "Baseline*" -NameMatch Wildcard -FilterScript { $_.TargetScope -eq 'Device' }
```

### Example 4 - Include settings

```powershell
Get-LKPolicy -Name "Firewall" -IncludeSettings | Select-Object Name, Settings
```

## Related

- [Get-LKPolicyOverview](Get-LKPolicyOverview.md) - at-a-glance assignment summary
- [Show-LKPolicyDetail](Show-LKPolicyDetail.md) - detailed formatted view
- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md) - assignment details
