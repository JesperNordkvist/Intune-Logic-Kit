---
title: Test-LKPolicyAssignment
nav_order: 27
---

# Test-LKPolicyAssignment

Audits Intune policies for scope mismatches - device policies assigned to user groups or vice versa.

## Syntax

```text
Test-LKPolicyAssignment
    [-PolicyType <String[]>]
    [-Name <String[]>]
    [-NameMatch <String>]
    [-Detailed]
    [<CommonParameters>]
```

## Description

Iterates all (or filtered) policy types, resolves each policy's effective scope, fetches assignments, determines each assigned group's scope via transitive membership, and flags mismatches.

Scope resolution uses multiple strategies: static registry defaults, Graph metadata (template info, ADMX class type), and a name-based heuristic (`- U -` = User, `- D -` / `- C -` = Device).

Group scope results are cached to avoid redundant API calls across policies that share the same groups.

## Parameters

### -PolicyType

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

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

### -Detailed

Shows a formatted, color-coded summary in the host. Mismatches in red, warnings in yellow.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyName | String | Policy display name |
| PolicyType | String | Human-readable type label |
| PolicyTypeId | String | Normalised type key |
| PolicyScope | String | Resolved scope (Device or User) |
| AssignmentType | String | Include or Exclude |
| GroupName | String | Mismatched group name |
| GroupScope | String | Group's effective scope |
| DeviceCount | Int | Device members in the group |
| UserCount | Int | User members in the group |
| Severity | String | Mismatch, Warning, or Info |
| Detail | String | Human-readable explanation |

## Examples

### Example 1 - Full audit

```powershell
Test-LKPolicyAssignment -Detailed
```

### Example 2 - Filter by type

```powershell
Test-LKPolicyAssignment -PolicyType SettingsCatalog, CompliancePolicy
```

### Example 3 - Programmatic filtering

```powershell
Test-LKPolicyAssignment | Where-Object Severity -eq 'Mismatch' | Format-Table PolicyName, PolicyScope, GroupName, GroupScope
```

### Example 4 - Remediate mismatches

```powershell
$mismatches = Test-LKPolicyAssignment | Where-Object Severity -eq 'Mismatch'
foreach ($m in $mismatches) {
    Remove-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $m.GroupName -Confirm:$false
    $correctGroup = if ($m.PolicyScope -eq 'Device') { "Device-Group" } else { "User-Group" }
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $correctGroup -Confirm:$false
}
```

## Related

- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md)
- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
