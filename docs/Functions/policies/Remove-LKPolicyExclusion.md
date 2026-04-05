---
title: Remove-LKPolicyExclusion
nav_order: 23
---

# Remove-LKPolicyExclusion

Removes a group exclusion from one or more Intune policies.

## Syntax

```text
# By name
Remove-LKPolicyExclusion
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-SearchPolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# All policies
Remove-LKPolicyExclusion
    -GroupName <String>
    -All
    [-PolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Remove-LKPolicyExclusion
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

Fetches current assignments, removes the matching exclusion, and writes back the updated set.

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

### -All

Remove the exclusion from all policies.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -PolicyType

Restrict to specific types when using `-All`.

| Attribute | Value |
|---|---|
| Type | `String[]` |

### -InputObject

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyName | String | Modified policy name |
| PolicyType | String | Normalised type key |
| Action | String | `ExclusionRemoved` |
| GroupName | String | Group name |
| GroupId | String | Group GUID |

## Examples

### Example 1 - Remove from all policies

```powershell
Remove-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
```

### Example 2 - Pipeline

```powershell
Get-LKPolicy -Name "Contoso" | Remove-LKPolicyExclusion -GroupName 'TestGroup'
```

## Related

- [Add-LKPolicyExclusion](Add-LKPolicyExclusion.md)
