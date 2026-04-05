---
title: Rename-LKPolicy
nav_order: 25
---

# Rename-LKPolicy

Renames an Intune policy.

## Syntax

```text
# Pipeline
Rename-LKPolicy
    [-InputObject <PSCustomObject>]
    -NewName <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Rename-LKPolicy
    -PolicyId <String>
    [-PolicyType <String>]
    -NewName <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

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

### -NewName

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyType | String | Normalised type key |
| OldName | String | Previous name |
| NewName | String | Updated name |
| Action | String | `Renamed` |

## Examples

### Example 1 - Pipeline

```powershell
Get-LKPolicy -Name "Old Policy Name" -NameMatch Exact | Rename-LKPolicy -NewName "New Policy Name"
```

### Example 2 - By ID

```powershell
Rename-LKPolicy -PolicyId 'abc-123' -NewName "New Name"
```

## Related

- [Get-LKPolicy](Get-LKPolicy.md)
