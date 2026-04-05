---
title: Rename-LKGroup
nav_order: 24
---

# Rename-LKGroup
Renames an existing Entra ID group.

## Syntax
```text
# By name
Rename-LKGroup -Name <String> -NewName <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By ID
Rename-LKGroup -GroupId <String> -NewName <String> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## Parameters

### -Name
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByName) |

### -GroupId
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -NewName
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

## Outputs
| Property | Type | Description |
|---|---|---|
| GroupId | String | Group GUID |
| OldName | String | Previous name |
| NewName | String | Updated name |
| Action | String | `Renamed` |

## Examples
```powershell
Rename-LKGroup -Name 'SG-Old-Name' -NewName 'SG-New-Name'
```

## Related
- [Get-LKGroup](Get-LKGroup.md)
