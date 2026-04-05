---
title: Get-LKGroup
nav_order: 9
---

# Get-LKGroup
Queries Entra ID groups with flexible name filtering.

## Syntax
```text
Get-LKGroup
    [-Name <String[]>]
    [-NameMatch <String>]
    [-FilterScript <ScriptBlock>]
    [<CommonParameters>]
```

## Parameters

### -Name
| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

### -NameMatch
| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -FilterScript
| Attribute | Value |
|---|---|
| Type | `ScriptBlock` |

## Outputs
| Property | Type | Description |
|---|---|---|
| Id | String | Group GUID |
| Name | String | Display name |
| Description | String | Group description |
| GroupType | String | Security group type |
| MembershipType | String | Assigned or Dynamic |
| MembershipRule | String | Dynamic membership rule (if applicable) |

## Examples

### Example 1 - Wildcard search
```powershell
Get-LKGroup -Name "SG-Windows-*" -NameMatch Wildcard
```

### Example 2 - Exact match
```powershell
Get-LKGroup -Name "SG-Intune-D-Pilot Devices" -NameMatch Exact
```

## Related
- [New-LKGroup](New-LKGroup.md)
- [Get-LKGroupAssignment](Get-LKGroupAssignment.md)
- [Get-LKGroupMember](Get-LKGroupMember.md)
