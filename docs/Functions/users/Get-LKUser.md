---
title: Get-LKUser
nav_order: 16
---

# Get-LKUser
Queries Entra ID users with flexible name and department filtering.

## Syntax
```text
Get-LKUser
    [-Name <String[]>]
    [-NameMatch <String>]
    [-Department <String>]
    [-FilterScript <ScriptBlock>]
    [<CommonParameters>]
```

## Parameters

### -Name
Search by display name or UPN.
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

### -Department
Filter by department name.
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -FilterScript
| Attribute | Value |
|---|---|
| Type | `ScriptBlock` |

## Outputs
| Property | Type | Description |
|---|---|---|
| Id | String | User object ID |
| DisplayName | String | Full name |
| UserPrincipalName | String | UPN |
| Mail | String | Email address |
| JobTitle | String | Job title |
| Department | String | Department |
| AccountEnabled | Boolean | Account status |

## Examples

### Example 1 - Search by name
```powershell
Get-LKUser -Name "John" -NameMatch Contains
```

### Example 2 - Search by UPN
```powershell
Get-LKUser -Name "john.doe@contoso.com" -NameMatch Exact
```

### Example 3 - Filter by department
```powershell
Get-LKUser -Department "IT"
```

## Related
- [Get-LKDevice](../devices/Get-LKDevice.md)
- [Add-LKGroupMember](../groups/Add-LKGroupMember.md)
