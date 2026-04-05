---
title: Remove-LKGroupMember
nav_order: 21
---

# Remove-LKGroupMember
Removes a device or user from an Entra ID group.

## Syntax
```text
# By device name
Remove-LKGroupMember -GroupName <String> -DeviceName <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By device ID
Remove-LKGroupMember -GroupName <String> -DeviceId <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By user name
Remove-LKGroupMember -GroupName <String> -UserName <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By user ID
Remove-LKGroupMember -GroupName <String> -UserId <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# Pipeline
Remove-LKGroupMember -GroupName <String> [-InputObject <PSCustomObject>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## Parameters

### -GroupName
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -DeviceName
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByDeviceName) |

### -DeviceId
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByDeviceId) |

### -UserName
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByUserName) |

### -UserId
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByUserId) |

### -InputObject
| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

## Outputs
| Property | Type | Description |
|---|---|---|
| GroupName | String | Target group name |
| GroupId | String | Target group GUID |
| MemberName | String | Removed member name |
| MemberId | String | Removed member ID |
| MemberType | String | Device or User |
| Action | String | `MemberRemoved` |

## Examples

### Example 1 - Remove device
```powershell
Remove-LKGroupMember -GroupName 'SG-Intune-TestDevices' -DeviceName 'YOURPC-001'
```

### Example 2 - Pipeline
```powershell
Get-LKDevice -User "John" | Remove-LKGroupMember -GroupName 'SG-Intune-TestDevices'
```

## Related
- [Add-LKGroupMember](Add-LKGroupMember.md)
