---
title: Get-LKPolicyOverview
nav_order: 14
---

# Get-LKPolicyOverview

Displays a formatted overview of all policies and their assignments at a glance.

## Syntax

```text
Get-LKPolicyOverview
    [-Name <String[]>]
    [-NameMatch <String>]
    [-PolicyType <String[]>]
    [-Unassigned]
    [<CommonParameters>]
```

## Description

Queries all (or filtered) policies, fetches their assignments, and renders a color-coded summary with one line per assignment, grouped by policy. Policies with no assignments are shown in dark gray. Excludes are highlighted in magenta, broad targets in cyan. App assignments show their intent (Required/Available/Uninstall).

## Parameters

### -Name

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

### -PolicyType

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -Unassigned

Show only policies that have no assignments.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

This command writes formatted output to the host. It does not emit pipeline objects.

## Examples

### Example 1 - Full overview

```powershell
Get-LKPolicyOverview
```

### Example 2 - Filter by type

```powershell
Get-LKPolicyOverview -PolicyType SettingsCatalog
```

### Example 3 - App assignments with intent

```powershell
Get-LKPolicyOverview -PolicyType App
```

Shows apps with their intent labels: `AllLicensedUsers (Required)`, `Include: GroupName (Available)`, etc.

### Example 4 - Find unassigned policies

```powershell
Get-LKPolicyOverview -Unassigned
```

## Related

- [Get-LKPolicy](Get-LKPolicy.md)
- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md)
