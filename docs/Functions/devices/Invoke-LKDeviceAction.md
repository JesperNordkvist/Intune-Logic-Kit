---
title: Invoke-LKDeviceAction
nav_order: 17
---

# Invoke-LKDeviceAction
Triggers a remote action on an Intune managed device.

## Syntax
```text
# By device name
Invoke-LKDeviceAction
    -Action <String>
    -DeviceName <String>
    [-KeepUserData] [-KeepEnrollmentData]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By device ID
Invoke-LKDeviceAction
    -Action <String>
    -DeviceId <String>
    [-KeepUserData] [-KeepEnrollmentData]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Invoke-LKDeviceAction
    -Action <String>
    [-InputObject <PSCustomObject>]
    [-KeepUserData] [-KeepEnrollmentData]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Parameters

### -Action
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |
| Valid values | Sync, Restart, RemoteLock, Retire, Wipe |

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

### -InputObject
| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -KeepUserData
For Wipe action: preserve user data on the device.
| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -KeepEnrollmentData
For Wipe action: preserve enrollment data on the device.
| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs
| Property | Type | Description |
|---|---|---|
| DeviceName | String | Target device |
| DeviceId | String | Device GUID |
| Action | String | Action performed |
| Status | String | `Initiated` |

## Examples

### Example 1 - Sync a device
```powershell
Invoke-LKDeviceAction -DeviceName 'YOURPC-001' -Action Sync
```

### Example 2 - Restart via pipeline
```powershell
Get-LKDevice -User "John" | Invoke-LKDeviceAction -Action Restart
```

### Example 3 - Wipe with data preservation
```powershell
Invoke-LKDeviceAction -DeviceName 'YOURPC-001' -Action Wipe -KeepUserData
```

## Related
- [Get-LKDevice](Get-LKDevice.md)
- [Get-LKDeviceDetail](Get-LKDeviceDetail.md)
