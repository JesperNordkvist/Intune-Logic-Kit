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
    [-Platform <String[]>]
    [-Name <String[]>]
    [-NameMatch <String>]
    [-Detailed]
    [-DisplayAs <String>]
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
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App, AutopilotDeploymentProfile |

### -Platform

Restrict App results to one or more platforms. Applies only to the `App` policy type (derived from each app's `@odata.type`); ignored with a warning if `App` is not in scope.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | Android, iOS, macOS, Windows, Web |

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

### -DisplayAs

Controls output format. Default shows full object properties (List). Table shows a compact view with key columns sized to fit the data.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | List |
| Valid values | List, Table |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyName | String | Policy display name |
| PolicyType | String | Human-readable type label |
| PolicyTypeId | String | Normalised type key |
| PolicyScope | String | Resolved scope (Device or User) |
| AssignmentType | String | Include, Exclude, AllDevices, AllUsers, or AllLicensedUsers |
| GroupName | String | Mismatched group name |
| GroupScope | String | Group's effective scope |
| DeviceCount | Int | Device members in the group |
| UserCount | Int | User members in the group |
| FilterId | String | Intune assignment filter ID, if one is attached |
| FilterName | String | `"FilterName (Include\|Exclude)"` when a filter is attached, otherwise `$null` |
| FilterType | String | Raw filter mode from Graph (`include` / `exclude`) |
| Severity | String | Mismatch, Warning, or Info |
| Detail | String | Human-readable explanation |

When `-DisplayAs Table` is used, the table includes `AssignmentType` and (conditionally) `FilterName` so you can see at a glance whether a flagged assignment is an inclusion, an exclusion, or scoped by an assignment filter - matching the columns shown by `Get-LKPolicyAssignment`.

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

### Example 4 - Compact table view with filter columns

```powershell
Test-LKPolicyAssignment -Severity Mismatch -DisplayAs Table
```

Renders the findings as a colour-coded table including `AssignmentType` and `FilterName` (the latter only appears when at least one issue has a filter attached). Useful when triaging large audits - exclusions and filtered assignments are visible without expanding objects.

### Example 5 - Remediate mismatches

> **⚠️ Warning - bulk remediation rewrites live policy assignments.**
> The loop below removes and re-adds group assignments across every flagged
> policy. Always run it as a `-WhatIf` dry run first, review the output line by
> line, and confirm the replacement group names are correct for your tenant
> before applying it. A wrong group name will strip a working assignment.

The loop remediates only the findings that are safe to automate, and
deliberately leaves two categories for manual review:

- **Group-based mismatches only** (`AssignmentType` of `Include` or `Exclude`).
  Broad-target findings (`AllDevices` / `AllUsers` / `AllLicensedUsers`) are
  skipped - removing "All Users" from a policy has a far larger blast radius.
  Handle those by hand with the `-AllDevices` / `-AllLicensedUsers` switches on
  [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md) /
  [Remove-LKPolicyAssignment](Remove-LKPolicyAssignment.md).
- **`GroupPolicyConfiguration` (ADMX) policies are skipped.** ADMX policies can
  legitimately carry both user- and machine-class settings and be validly
  assigned to either group type, so they must not be auto-remediated.

```powershell
# Replace these with the real target groups for your tenant.
$deviceGroup = 'SG-Intune-D-Pilot Devices'
$userGroup   = 'SG-Intune-U-Pilot Users'

$mismatches = Test-LKPolicyAssignment |
    Where-Object {
        $_.Severity       -eq 'Mismatch' -and
        $_.AssignmentType -in 'Include', 'Exclude' -and
        $_.PolicyTypeId   -ne 'GroupPolicyConfiguration'
    }

foreach ($m in $mismatches) {
    $correctGroup = if ($m.PolicyScope -eq 'Device') { $deviceGroup } else { $userGroup }

    # Dry run - inspect the output, then drop -WhatIf to apply.
    Remove-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $m.GroupName -WhatIf
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $correctGroup -WhatIf
}
```

Once the `-WhatIf` output is verified, replace `-WhatIf` with `-Confirm:$false`
to apply the changes.

## Related

- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md)
- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
