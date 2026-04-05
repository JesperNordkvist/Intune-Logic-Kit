---
title: New-LKGroup
nav_order: 18
---

# New-LKGroup
Creates a new Entra ID security group for Intune.

## Syntax
```text
New-LKGroup
    -Name <String>
    [-Description <String>]
    [-GroupType <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Parameters

### -Name
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -Description
| Attribute | Value |
|---|---|
| Type | `String` |
| Default | (empty) |

### -GroupType
| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Device |
| Valid values | Device, User |

## Outputs
| Property | Type | Description |
|---|---|---|
| Id | String | New group GUID |
| Name | String | Display name |
| Description | String | Group description |
| GroupType | String | Security group type |
| MembershipType | String | Assigned |
| MembershipRule | String | null |

## Examples

### Example 1 - Device group
```powershell
New-LKGroup -Name 'SG-Intune-TestDevices' -Description 'Test device group'
```

### Example 2 - User group
```powershell
New-LKGroup -Name 'SG-Intune-TestUsers' -Description 'Test users' -GroupType User
```

## Related
- [Remove-LKGroup](Remove-LKGroup.md)
- [Rename-LKGroup](Rename-LKGroup.md)
