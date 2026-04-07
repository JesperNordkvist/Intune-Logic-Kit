---
title: Copy-LKPolicyAssignment
nav_order: 6
---

# Copy-LKPolicyAssignment

Copies a group's policy assignments to another group.

## Syntax

```text
Copy-LKPolicyAssignment
    -SourceGroup <String>
    -TargetGroup <String>
    [-PolicyType <String[]>]
    [-AssignmentType <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

Finds all policies where the source group is assigned, then assigns the target group to those same policies. Skips policies where the target group is already assigned. Only explicit group assignments (Include/Exclude) are copied — broad targets (All Devices, All Users) are tenant-wide and not copied.

App intent (Required, Available, Uninstall) is carried over automatically.

## Parameters

### -SourceGroup

Name of the group whose assignments to copy from. Must match exactly one group.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -TargetGroup

Name of the group to assign to the same policies.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -PolicyType

Restrict to specific policy types.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -AssignmentType

Which assignment types to copy. Default: `Include`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Include |
| Valid values | Include, Exclude, All |

### -WhatIf

Shows what would happen without performing the action.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -Confirm

Prompts for confirmation before performing the action.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyName | String | Policy display name |
| PolicyType | String | Normalised type key |
| DisplayType | String | Human-readable type label |
| AssignmentType | String | Include or Exclude |
| Intent | String | App intent if applicable |
| SourceGroup | String | Group copied from |
| TargetGroup | String | Group copied to |
| Action | String | `AssignmentCopied` |

## Examples

### Example 1 - Copy all assignments

```powershell
Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Autopilot Pilot Devices"
```

### Example 2 - Preview with WhatIf

```powershell
Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Production Devices" -WhatIf
```

### Example 3 - Copy only Settings Catalog assignments

```powershell
Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Production Devices" -PolicyType SettingsCatalog
```

### Example 4 - Copy both includes and excludes

```powershell
Copy-LKPolicyAssignment -SourceGroup "Pilot Devices" -TargetGroup "Production Devices" -AssignmentType All
```

## Related

- [Get-LKGroupAssignment](../groups/Get-LKGroupAssignment.md)
- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
