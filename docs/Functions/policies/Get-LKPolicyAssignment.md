---
title: Get-LKPolicyAssignment
nav_order: 13
---

# Get-LKPolicyAssignment

Shows the assignment details (includes, excludes, intent) for one or more policies.

## Syntax

```text
# Pipeline
Get-LKPolicyAssignment
    [-InputObject <PSCustomObject>]
    [-DisplayAs <String>]
    [<CommonParameters>]

# By ID
Get-LKPolicyAssignment
    -PolicyId <String>
    [-PolicyType <String>]
    [-DisplayAs <String>]
    [<CommonParameters>]
```

## Description

For each policy, fetches all assignments from the Graph API and returns structured objects with group names resolved. Supports pipeline input from `Get-LKPolicy`. Group names are cached within the call to avoid redundant lookups.

## Parameters

### -InputObject

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -PolicyId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -PolicyType

Optional - auto-resolved if omitted.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

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
| AssignmentType | String | Include, Exclude, AllDevices, AllUsers, or AllLicensedUsers |
| GroupId | String | Target group GUID (null for broad targets) |
| GroupName | String | Target group display name |
| FilterType | String | Assignment filter type (if configured) |
| FilterId | String | Assignment filter GUID (if configured) |
| Intent | String | required, available, or uninstall (apps only) |

## Examples

### Example 1 - Pipeline

```powershell
Get-LKPolicy -Name "Contoso" | Get-LKPolicyAssignment
```

### Example 2 - By ID

```powershell
Get-LKPolicyAssignment -PolicyId 'abc-123'
```

### Example 3 - Filter to exclusions

```powershell
Get-LKPolicy -Name "Firewall" | Get-LKPolicyAssignment | Where-Object AssignmentType -eq 'Exclude'
```

### Example 4 - App intent

```powershell
Get-LKPolicy -PolicyType App | Get-LKPolicyAssignment | Format-Table PolicyName, AssignmentType, GroupName, Intent
```

## Related

- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
- [Remove-LKPolicyAssignment](Remove-LKPolicyAssignment.md)
