---
title: Export-LKPolicy
nav_order: 7
---

# Export-LKPolicy

Exports Intune policies and their settings to JSON or CSV.

## Syntax

```text
# Pipeline
Export-LKPolicy
    [-InputObject <PSCustomObject>]
    -Path <String>
    [-Format <String>]
    [-IncludeSettings]
    [-IncludeAssignments]
    [<CommonParameters>]

# By type
Export-LKPolicy
    [-PolicyType <String[]>]
    -Path <String>
    [-Format <String>]
    [-IncludeSettings]
    [-IncludeAssignments]
    [<CommonParameters>]

# All
Export-LKPolicy
    -All
    -Path <String>
    [-Format <String>]
    [-IncludeSettings]
    [-IncludeAssignments]
    [<CommonParameters>]
```

## Description

Fetches policies (with optional settings and assignments) and exports them to a file for documentation, auditing, or migration purposes. Supports JSON and CSV formats. The format is auto-detected from the file extension if not specified.

In CSV format, the output is flattened to one row per setting. In JSON format, the full structure is preserved including nested settings and assignments.

## Parameters

### -InputObject

A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -PolicyType

Export only specific policy types.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App, AutopilotDeploymentProfile |

### -All

Export all policies across all types.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -Path

Output file path. Required.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -Format

Output format. Auto-detected from file extension if omitted.

| Attribute | Value |
|---|---|
| Type | `String` |
| Valid values | JSON, CSV |

### -IncludeSettings

Fetches and includes all configured settings for each policy.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -IncludeAssignments

Fetches and includes assignment details for each policy.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Examples

### Example 1 - Export to JSON

```powershell
Get-LKPolicy -PolicyType SettingsCatalog | Export-LKPolicy -Path .\policies.json
```

### Example 2 - Export with settings to CSV

```powershell
Get-LKPolicy -Name "Baseline" | Export-LKPolicy -Path .\baseline.csv -IncludeSettings
```

CSV output has one row per setting: PolicyName, PolicyType, TargetScope, SettingName, Value, Category.

### Example 3 - Full tenant export

```powershell
Export-LKPolicy -All -IncludeSettings -IncludeAssignments -Path .\full-export.json
```

### Example 4 - Export specific types

```powershell
Export-LKPolicy -PolicyType CompliancePolicy, EndpointSecurity -IncludeSettings -Path .\security.json
```

## Related

- [Get-LKPolicy](Get-LKPolicy.md)
- [Search-LKSetting](Search-LKSetting.md)
