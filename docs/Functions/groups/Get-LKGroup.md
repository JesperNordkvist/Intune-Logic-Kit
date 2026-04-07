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
    [-DisplayAs <String>]
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
