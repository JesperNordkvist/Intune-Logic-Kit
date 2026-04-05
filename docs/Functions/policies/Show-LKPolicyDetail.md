---
title: Show-LKPolicyDetail
nav_order: 26
---

# Show-LKPolicyDetail

Displays a detailed, formatted view of one or more Intune policies including all configured settings.

## Syntax

```text
# Pipeline
Show-LKPolicyDetail
    [-InputObject <PSCustomObject>]
    [<CommonParameters>]

# By ID
Show-LKPolicyDetail
    -PolicyId <String>
    [-PolicyType <String>]
    [<CommonParameters>]
```

## Description

Fetches the full settings for each policy and renders them in a readable grouped format. Shows policy metadata (type, scope, created/modified dates), all assignments with intent labels, and all configured settings grouped by category. Accepts pipeline input from `Get-LKPolicy`.

## Parameters

### -InputObject

A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -PolicyId

The Graph object ID of the policy.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -PolicyType

The policy type key. Optional - if omitted, the type is auto-resolved by probing all endpoints.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

## Outputs

This command writes formatted output to the host. It does not emit pipeline objects.

## Examples

### Example 1 - Pipeline from Get-LKPolicy

```powershell
Get-LKPolicy -Name "Contoso - Baseline" | Show-LKPolicyDetail
```

### Example 2 - By ID

```powershell
Show-LKPolicyDetail -PolicyId 'abc-123' -PolicyType SettingsCatalog
```

### Example 3 - Multiple policies

```powershell
Get-LKPolicy -PolicyType SettingsCatalog -Name "Firewall" | Show-LKPolicyDetail
```

## Related

- [Get-LKPolicy](Get-LKPolicy.md)
- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md)
