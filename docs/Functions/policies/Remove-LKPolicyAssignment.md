---
title: Remove-LKPolicyAssignment
nav_order: 22
---

# Remove-LKPolicyAssignment

Removes a group include assignment from one or more Intune policies.

## Syntax

```text
# By name (default)
Remove-LKPolicyAssignment
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-SearchPolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Remove-LKPolicyAssignment
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Remove-LKPolicyAssignment
    -GroupName <String>
    -PolicyId <String>
    [-PolicyType <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

Fetches the current assignments, removes the matching group include, and writes back the updated set. Policies that don't include the group are silently skipped.

## Parameters

### -GroupName

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -PolicyName

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

### -SearchPolicyType

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

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

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyName | String | Modified policy name |
| PolicyType | String | Normalised type key |
| Action | String | `AssignmentRemoved` |
| GroupName | String | Removed group name |
| GroupId | String | Removed group GUID |

## Examples

### Example 1 - Pipeline

```powershell
Get-LKPolicy -Name "Contoso - TestConfig" | Remove-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
```

### Example 2 - By ID

```powershell
Remove-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
```

## Related

- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
- [Remove-LKPolicyExclusion](Remove-LKPolicyExclusion.md)
