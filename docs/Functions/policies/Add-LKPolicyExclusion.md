---
title: Add-LKPolicyExclusion
nav_order: 4
---

# Add-LKPolicyExclusion

Adds a group as an exclusion to one or more Intune policies.

## Syntax

```text
# By name
Add-LKPolicyExclusion
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-SearchPolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# All policies
Add-LKPolicyExclusion
    -GroupName <String>
    -All
    [-PolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Add-LKPolicyExclusion
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

For each target policy: fetches current assignments, appends an exclusion entry, and writes back the complete set. Skips policies that already exclude the group.

Use `-All` to exclude a group from every policy in the tenant (or filtered by `-PolicyType`).

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

Exclude the group from all policies in the tenant.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -PolicyType

When used with `-All`, restricts which policy types are affected.

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
| Action | String | `ExclusionAdded` |
| GroupName | String | Excluded group name |
| GroupId | String | Excluded group GUID |

## Examples

### Example 1 - Exclude from all policies

```powershell
Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
```

### Example 2 - Exclude from compliance only

```powershell
Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All -PolicyType CompliancePolicy
```

### Example 3 - Preview with WhatIf

```powershell
Add-LKPolicyExclusion -GroupName 'TestGroup' -All -WhatIf
```

## Related

- [Remove-LKPolicyExclusion](Remove-LKPolicyExclusion.md)
- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
