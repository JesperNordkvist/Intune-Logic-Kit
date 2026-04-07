---
title: Get-LKGroupAssignment
nav_order: 10
---

# Get-LKGroupAssignment

Finds all Intune policies where a specific group is assigned - a reverse lookup across all policy types.

## Syntax

```text
# By name
Get-LKGroupAssignment
    -Name <String[]>
    [-NameMatch <String>]
    [-PolicyType <String[]>]
    [-SkipScopeResolution]
    [-AssignmentType <String>]
    [-DisplayAs <String>]
    [<CommonParameters>]

# By ID
Get-LKGroupAssignment
    -GroupId <String>
    [-PolicyType <String[]>]
    [-SkipScopeResolution]
    [-AssignmentType <String>]
    [-DisplayAs <String>]
    [<CommonParameters>]
```

## Description

Iterates across all policy types and checks each policy's assignments for the specified group(s). Also includes broad targets ("All Devices", "All Users", "All Licensed Users") when they would effectively target the group based on its member scope. A device group will see "All Devices" policies, a user group will see "All Users" policies, and mixed groups see both. Groups that are explicitly excluded from a policy are filtered out.

Policy scope is automatically resolved via Graph metadata so that `ScopeMismatch` is accurate. Use `-SkipScopeResolution` for faster results.

## Parameters

### -Name

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ByName) |

### -NameMatch

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -GroupId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -PolicyType

Restrict to specific policy types.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -SkipScopeResolution

Skip dynamic scope resolution for faster results. `ScopeMismatch` will be `$null` for 'Both'-scoped policy types.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -AssignmentType

Filter by assignment type. Default: `All` (shows includes, excludes, and broad targets).

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | All |
| Valid values | Include, Exclude, All |

### -DisplayAs

Controls output format. Default shows full object properties (List). Table shows a compact view with key columns sized to fit the data.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | List |
| Valid values | List, Table |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyName | String | Policy display name |
| PolicyType | String | Normalised type key |
| DisplayType | String | Human-readable type label |
| PolicyScope | String | Resolved scope |
| AssignmentType | String | Include, Exclude, AllDevices, AllUsers, AllLicensedUsers |
| GroupId | String | Group GUID |
| GroupName | String | Group display name |
| GroupScope | String | Group's effective scope |
| ScopeMismatch | Boolean | True if scopes conflict |
| Intent | String | required, available, or uninstall (apps only) |

## Examples

### Example 1 - Basic reverse lookup

```powershell
Get-LKGroupAssignment -Name 'SG-Intune-D-Pilot Devices' -NameMatch Exact
```

### Example 2 - Find scope mismatches

```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' | Where-Object ScopeMismatch
```

### Example 3 - Exclusions only

```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType Exclude
```

### Example 4 - Filter by policy type

```powershell
Get-LKGroupAssignment -Name 'Pilot' -PolicyType CompliancePolicy, SettingsCatalog
```

### Example 5 - App assignments with intent

```powershell
Get-LKGroupAssignment -Name 'All Users' -PolicyType App | Format-Table PolicyName, Intent
```

## Related

- [Get-LKGroup](Get-LKGroup.md)
- [Get-LKPolicyAssignment](../policies/Get-LKPolicyAssignment.md)
