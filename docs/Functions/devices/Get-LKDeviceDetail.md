---
title: Get-LKDeviceDetail
nav_order: 8
---

# Get-LKDeviceDetail
Returns detailed information for a specific Intune managed device.

## Syntax
```text
# By name
Get-LKDeviceDetail -Name <String> [<CommonParameters>]

# By ID
Get-LKDeviceDetail -DeviceId <String> [<CommonParameters>]

# Pipeline
Get-LKDeviceDetail [-InputObject <PSCustomObject>] [<CommonParameters>]
```

## Parameters

### -Name
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByName) |

### -DeviceId
| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -InputObject
A device object from `Get-LKDevice`. Accepted from the pipeline.
| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

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
| Manufacturer | String | Manufacturer |
| SerialNumber | String | Serial number |
| AzureADDeviceId | String | Entra device ID |
| EnrollmentType | String | How the device was enrolled |
| JoinType | String | Azure AD join type |
| Ownership | String | Corporate or Personal |
| TotalStorageGB | Decimal | Total storage |
| FreeStorageGB | Decimal | Free storage |
| EncryptionState | String | Encryption status |
| ComplianceGracePeriod | DateTime | Grace period expiry |
| PrimaryUser | String | Primary user info |
| CompliancePolicyStates | Array | Compliance policy status |
| ConfigurationStates | Array | Configuration profile status |

## Examples

### Example 1 - By name
```powershell
Get-LKDeviceDetail -Name "YOURPC-001"
```

### Example 2 - Pipeline
```powershell
Get-LKDevice -User "John" | Get-LKDeviceDetail
```

## Related
- [Get-LKDevice](Get-LKDevice.md)
- [Invoke-LKDeviceAction](Invoke-LKDeviceAction.md)
