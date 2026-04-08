---
title: Compare-LKDevice
nav_order: 6
---

# Compare-LKDevice

Compares two or more Intune managed devices side by side.

## Syntax

```text
# Pipeline
Compare-LKDevice
    [-InputObject <PSCustomObject>]
    [-IncludeApps]
    [-IncludeEqual]
    [<CommonParameters>]

# By name
Compare-LKDevice
    -DeviceName <String[]>
    [-IncludeApps]
    [-IncludeEqual]
    [<CommonParameters>]

# By ID
Compare-LKDevice
    -DeviceId <String[]>
    [-IncludeApps]
    [-IncludeEqual]
    [<CommonParameters>]
```

## Description

Fetches device details and optionally discovered apps for each device, then shows differences. Useful for detecting drift between devices, such as comparing an AVD production device against its golden image.

Compares the following device properties: OS, OS version, compliance state, management state, enrollment type, join type, ownership, manufacturer, model, serial number, encryption, storage, enrollment date, last sync, and primary user.

With `-IncludeApps`, also compares all discovered applications and their versions.

## Parameters

### -InputObject

A device object from `Get-LKDevice`. Accepted from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -DeviceName

One or more device names to compare.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ByName) |

### -DeviceId

One or more Intune managed device IDs to compare.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ById) |

### -IncludeApps

Fetches and compares discovered apps and their versions across the devices.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -IncludeEqual

When specified, also shows properties and apps that are identical across all devices.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

This command writes formatted output to the host. It does not emit pipeline objects.

## Examples

### Example 1 - Compare two devices by name

```powershell
Compare-LKDevice -DeviceName "AVD-PROD-01", "AVD-GOLD-01"
```

Shows property differences between the two devices.

### Example 2 - Include app comparison

```powershell
Compare-LKDevice -DeviceName "AVD-PROD-01", "AVD-GOLD-01" -IncludeApps
```

Also compares installed apps and their versions — ideal for detecting AVD image drift.

### Example 3 - Pipeline from Get-LKDevice

```powershell
Get-LKDevice -Name "AVD-PROD-01", "AVD-GOLD-01" -NameMatch Exact | Compare-LKDevice -IncludeApps
```

### Example 4 - Show everything including matches

```powershell
Compare-LKDevice -DeviceName "PC-001", "PC-002" -IncludeApps -IncludeEqual
```

## Related

- [Get-LKDevice](Get-LKDevice.md)
- [Get-LKDeviceDetail](Get-LKDeviceDetail.md)
