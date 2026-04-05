---
title: Add-LKGroupMember
nav_order: 2
---

# Add-LKGroupMember
Adds a device or user to an Entra ID group.

## Syntax
```text
# By device name
Add-LKGroupMember -GroupName <String> -DeviceName <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By device ID
Add-LKGroupMember -GroupName <String> -DeviceId <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By user name
Add-LKGroupMember -GroupName <String> -UserName <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# By user ID
Add-LKGroupMember -GroupName <String> -UserId <String> [-WhatIf] [-Confirm] [<CommonParameters>]

# Pipeline
Add-LKGroupMember -GroupName <String> [-InputObject <PSCustomObject>] [-WhatIf] [-Confirm] [<CommonParameters>]
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
A device or user object. Accepted from the pipeline.
| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

## Outputs
| Property | Type | Description |
|---|---|---|
| GroupName | String | Target group name |
| GroupId | String | Target group GUID |
| MemberName | String | Added member name |
| MemberId | String | Added member ID |
| MemberType | String | Device or User |
| Action | String | `MemberAdded` |

## Examples

### Example 1 - Add device by name
```powershell
Add-LKGroupMember -GroupName 'SG-Intune-TestDevices' -DeviceName 'YOURPC-001'
```

### Example 2 - Pipeline from Get-LKDevice
```powershell
Get-LKDevice -User "John" | Add-LKGroupMember -GroupName 'SG-Intune-TestDevices'
```

### Example 3 - Add user
```powershell
Get-LKUser -Name "John" | Add-LKGroupMember -GroupName 'SG-Intune-TestUsers'
```

## Related
- [Remove-LKGroupMember](Remove-LKGroupMember.md)
- [Get-LKGroupMember](Get-LKGroupMember.md)
