---
title: Get-LKGroupMember
nav_order: 11
---

# Get-LKGroupMember

Lists the members of an Entra ID group.

## Syntax

```text
# By name
Get-LKGroupMember -GroupName <String> [-MemberType <String>] [-DisplayAs <String>] [<CommonParameters>]

# By ID
Get-LKGroupMember -GroupId <String> [-MemberType <String>] [-DisplayAs <String>] [<CommonParameters>]

# Pipeline
Get-LKGroupMember [-InputObject <PSCustomObject>] [-MemberType <String>] [-DisplayAs <String>] [<CommonParameters>]
```

## Parameters

### -GroupName

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByName) |

### -GroupId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -InputObject

A group object from `Get-LKGroup`. Accepted from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -MemberType

Filter to devices or users only. Default: `All`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | All |
| Valid values | All, Device, User |

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
| GroupName | String | Parent group name |
| GroupId | String | Parent group GUID |
| MemberId | String | Member object ID |
| DisplayName | String | Member display name |
| MemberType | String | Device or User |
| UserPrincipalName | String | UPN (users only) |
| DeviceId | String | Device ID (devices only) |
| OS | String | Operating system (devices only) |

## Examples

### Example 1 - List all members

```powershell
Get-LKGroupMember -GroupName 'SG-Intune-TestDevices'
```

### Example 2 - Devices only

```powershell
Get-LKGroupMember -GroupName 'SG-Intune-TestDevices' -MemberType Device
```

### Example 3 - Pipeline

```powershell
Get-LKGroup -Name 'SG-Test*' -NameMatch Wildcard | Get-LKGroupMember
```

## Related

- [Add-LKGroupMember](Add-LKGroupMember.md)
- [Remove-LKGroupMember](Remove-LKGroupMember.md)
