---
title: Remove-LKGroup
nav_order: 20
---

# Remove-LKGroup
Deletes an Entra ID group.

## Syntax
```text
# By name
Remove-LKGroup -Name <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By ID
Remove-LKGroup -GroupId <String> [-WhatIf] [-Confirm] [<CommonParameters>]
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

## Outputs
| Property | Type | Description |
|---|---|---|
| GroupId | String | Deleted group GUID |
| Name | String | Group name |
| Action | String | `Deleted` |

## Examples
```powershell
Remove-LKGroup -Name 'SG-Intune-TestDevices'
```

## Related
- [New-LKGroup](New-LKGroup.md)
