---
title: Test-LKPolicyConflict
nav_order: 28
---

# Test-LKPolicyConflict

Detects policies with overlapping settings assigned to the same groups.

## Syntax

```text
Test-LKPolicyConflict
    [-PolicyType <String[]>]
    [-Setting <String[]>]
    [-SettingMatch <String>]
    [-Detailed]
    [<CommonParameters>]
```

## Description

Scans policies, fetches their settings and assignments, then identifies cases where multiple policies configure the same setting and are assigned to at least one common group. These are potential conflicts where the winning policy depends on Intune's internal precedence rules.

Results are separated into two categories:

| Category | Meaning |
|---|---|
| **Conflicting values** | Same setting, same groups, but different values — one will win and the other is silently ignored |
| **Duplicate settings** | Same setting, same groups, same value — redundant but not harmful |

## Parameters

### -PolicyType

Restrict the scan to specific policy types. When omitted, all types are scanned.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App, AutopilotDeploymentProfile |

### -Setting

Filter to only check for conflicts involving specific settings.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

### -SettingMatch

How `-Setting` is matched. Default: `Contains`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -Detailed

Emits full `LKPolicyConflict` objects to the pipeline instead of the summary table.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

With `-Detailed`:

| Property | Type | Description |
|---|---|---|
| SettingName | String | The conflicting setting name |
| PolicyA | String | First policy name |
| PolicyAType | String | First policy type |
| ValueA | String | Value in the first policy |
| PolicyB | String | Second policy name |
| PolicyBType | String | Second policy type |
| ValueB | String | Value in the second policy |
| ValueMatch | Boolean | Whether both policies set the same value |
| CommonGroups | Int | Number of shared group assignments |
| CommonGroupIds | String[] | IDs of the shared groups |

## Examples

### Example 1 - Scan all policy types

```powershell
Test-LKPolicyConflict
```

### Example 2 - Scan specific types

```powershell
Test-LKPolicyConflict -PolicyType SettingsCatalog, DeviceConfiguration
```

### Example 3 - Check specific settings

```powershell
Test-LKPolicyConflict -Setting "Firewall" -Detailed
```

### Example 4 - Export conflicts

```powershell
Test-LKPolicyConflict -Detailed |
    Where-Object { -not $_.ValueMatch } |
    Export-Csv -Path .\conflicts.csv -NoTypeInformation
```

## Notes

- This function makes many API calls: it fetches settings AND assignments for every policy in scope. Use `-PolicyType` and `-Setting` to narrow the scan for faster results.
- "All Devices" and "All Users" broad targets are tracked and will match against each other across policies.
- The conflict detection is pairwise — if three policies share a setting and group, each pair is reported separately.

## Related

- [Search-LKSetting](Search-LKSetting.md) - find which policies configure a setting
- [Compare-LKPolicySetting](Compare-LKPolicySetting.md) - detailed side-by-side comparison
- [Test-LKPolicyAssignment](Test-LKPolicyAssignment.md) - scope mismatch auditing
