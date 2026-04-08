---
title: Compare-LKPolicySetting
nav_order: 5
---

# Compare-LKPolicySetting

Compares settings between two or more policies side by side.

## Syntax

```text
# Pipeline
Compare-LKPolicySetting
    [-InputObject <PSCustomObject>]
    [-IncludeEqual]
    [-DisplayAs <String>]
    [<CommonParameters>]

# By ID
Compare-LKPolicySetting
    -PolicyId <String[]>
    [-IncludeEqual]
    [-DisplayAs <String>]
    [<CommonParameters>]
```

## Description

Fetches settings for each policy and shows differences. By default only shows settings that differ between policies. Use `-IncludeEqual` to show all settings. Accepts pipeline input from `Get-LKPolicy`.

Each setting is marked as:

| Status | Meaning |
|---|---|
| **Different** | Setting exists in all policies but with different values |
| **Missing** | Setting exists in some policies but not others |
| **Equal** | Setting exists in all policies with the same value (only shown with `-IncludeEqual`) |

## Parameters

### -InputObject

A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -PolicyId

One or more Graph object IDs of policies to compare. The policy type is auto-resolved.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ById) |

### -IncludeEqual

When specified, also shows settings that are identical across all policies.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -DisplayAs

Controls output format. Table (default) renders a colored table to the host. List emits objects to the pipeline.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Table |
| Valid values | Table, List |

## Outputs

| Property | Type | Description |
|---|---|---|
| SettingName | String | Name of the setting |
| Status | String | Equal, Different, or Missing |
| *(PolicyName)* | String | One dynamic column per policy showing its value |

## Examples

### Example 1 - Compare policies by name

```powershell
Get-LKPolicy -Name "Baseline" -NameMatch Contains | Compare-LKPolicySetting
```

### Example 2 - Compare by ID

```powershell
Compare-LKPolicySetting -PolicyId 'abc-123', 'def-456'
```

### Example 3 - Include matching settings

```powershell
Get-LKPolicy -Name "Firewall" | Compare-LKPolicySetting -IncludeEqual
```

### Example 4 - Pipeline output for scripting

```powershell
Get-LKPolicy -Name "Compliance" | Compare-LKPolicySetting -DisplayAs List |
    Where-Object Status -eq 'Different' |
    Export-Csv -Path .\diffs.csv -NoTypeInformation
```

## Related

- [Get-LKPolicy](Get-LKPolicy.md)
- [Search-LKSetting](Search-LKSetting.md)
- [Test-LKPolicyConflict](Test-LKPolicyConflict.md)
