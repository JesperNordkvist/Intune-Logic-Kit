---
title: Get-LKDevice
nav_order: 7
---

# Get-LKDevice
Queries Intune managed devices with flexible filtering.

## Syntax
```text
Get-LKDevice
    [-Name <String[]>]
    [-NameMatch <String>]
    [-User <String[]>]
    [-UserMatch <String>]
    [-OS <String>]
    [-FilterScript <ScriptBlock>]
    [<CommonParameters>]
```

## Parameters

### -Name
Search by device name.
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

### -User
Search by primary user display name.
| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

### -UserMatch
How `-User` is matched.
| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -OS
Filter by operating system.
| Attribute | Value |
|---|---|
| Type | `String` |
| Valid values | Windows, iOS, Android, macOS |

### -FilterScript
| Attribute | Value |
|---|---|
| Type | `ScriptBlock` |

## Outputs
| Property | Type | Description |
|---|---|---|
| Id | String | Intune device ID |
| DeviceName | String | Device name |
| UserDisplayName | String | Primary user |
| UserPrincipalName | String | Primary user UPN |
| OS | String | Operating system |
| OSVersion | String | OS version |
| ComplianceState | String | Compliance status |
| ManagementState | String | Management status |
| EnrolledDateTime | DateTime | Enrollment date |
| LastSyncDateTime | DateTime | Last sync |
| Model | String | Hardware model |
| Manufacturer | String | Hardware manufacturer |
| SerialNumber | String | Serial number |
| AzureADDeviceId | String | Entra device ID |

## Examples

### Example 1 - Search by name
```powershell
Get-LKDevice -Name "YOURPC" -NameMatch Contains
```

### Example 2 - By user
```powershell
Get-LKDevice -User "John" -OS Windows
```

### Example 3 - Pipeline to group membership
```powershell
Get-LKDevice -User "John" | Add-LKGroupMember -GroupName 'SG-Intune-TestDevices'
```

## Related
- [Get-LKDeviceDetail](Get-LKDeviceDetail.md)
- [Invoke-LKDeviceAction](Invoke-LKDeviceAction.md)
