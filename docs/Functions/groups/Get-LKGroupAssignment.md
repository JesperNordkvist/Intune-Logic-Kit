---
title: Get-LKGroupAssignment
nav_order: 10
---

# Get-LKGroupAssignment

Finds all Intune policies where a specific group is assigned - a reverse lookup across all policy types.

## Syntax

```text
# By name
Get-LKGroupAssignment
    -Name <String[]>
    [-NameMatch <String>]
    [-PolicyType <String[]>]
    [-Platform <String[]>]
    [-SkipScopeResolution]
    [-AssignmentType <String>]
    [-DisplayAs <String>]
    [-Effective]
    [-AppliedOnly]
    [<CommonParameters>]

# By ID
Get-LKGroupAssignment
    -GroupId <String>
    [-PolicyType <String[]>]
    [-Platform <String[]>]
    [-SkipScopeResolution]
    [-AssignmentType <String>]
    [-DisplayAs <String>]
    [-Effective]
    [-AppliedOnly]
    [<CommonParameters>]
```

## Description

Iterates across all policy types and checks each policy's assignments for the specified group(s). Also includes broad targets ("All Devices", "All Users", "All Licensed Users") when they would effectively target the group based on its member scope. A device group will see "All Devices" policies, a user group will see "All Users" policies, and mixed groups see both. Groups that are explicitly excluded from a policy are filtered out.

Policy scope is automatically resolved via Graph metadata so that `ScopeMismatch` is accurate. Use `-SkipScopeResolution` for faster results.

## Parameters

### -Name

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ByName) |

### -NameMatch

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -GroupId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -PolicyType

Restrict to specific policy types.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -Platform

Restrict App results to one or more platforms. Applies only to the `App` policy type (derived from each app's `@odata.type`); ignored with a warning if `App` is not in scope. Because non-matching apps are skipped before their assignments are fetched, this also speeds up the scan considerably on app-heavy tenants.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | Android, iOS, macOS, Windows, Web |

### -SkipScopeResolution

Skip dynamic scope resolution for faster results. `ScopeMismatch` will be `$null` for 'Both'-scoped policy types.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -AssignmentType

Filter by assignment type. Default: `All` (shows includes, excludes, and broad targets).

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | All |
| Valid values | Include, Exclude, All |

### -DisplayAs

Controls output format. Default shows full object properties (List). Table shows a compact view with key columns sized to fit the data.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | List |
| Valid values | List, Table |

### -Effective

Collapses assignments across all named groups into one row per policy, applying Intune's per-scope Exclude-wins precedence. Use when you want to know, for a user in the user group(s) + a device in the device group(s), which policies actually apply.

Intune's real rule: Excludes only take effect for the scope (user or device) that matches the excluded group. A user-group Exclude cannot cancel a device's `AllDevices` delivery path, and vice versa. `-Effective` computes delivery per scope and combines them.

When `-Effective` is set, the output schema changes — see the Effective Outputs table below. `-AssignmentType` is ignored (forced to `All`).

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -AppliedOnly

Filters `-Effective` output to policies that actually deliver to the group(s) (`EffectiveState` of `Applied` or `Conditional`). `Excluded` and `NotApplied` rows are hidden. Implies `-Effective`.

Use when you want the answer to: "for a user in these groups on a device in these groups, what actually hits them?"

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyName | String | Policy display name |
| PolicyType | String | Normalised type key |
| DisplayType | String | Human-readable type label |
| PolicyScope | String | Resolved scope |
| AssignmentType | String | Include, Exclude, AllDevices, AllUsers, AllLicensedUsers |
| GroupId | String | Group GUID |
| GroupName | String | Group display name |
| GroupScope | String | Group's effective scope |
| ScopeMismatch | Boolean | True if scopes conflict |
| Intent | String | required, available, or uninstall (apps only) |
| FilterId | String | Assignment filter GUID (if configured) |
| FilterName | String | Assignment filter display name (if configured) |
| FilterType | String | Assignment filter mode (if configured) |

### Effective Outputs (with `-Effective`)

| Property | Type | Description |
|---|---|---|
| PolicyId | String | Graph object ID |
| PolicyName | String | Policy display name |
| PolicyType | String | Normalised type key |
| DisplayType | String | Human-readable type label |
| PolicyScope | String | Resolved scope |
| EffectiveState | String | `Applied`, `Conditional` (delivered only via filtered assignment), `Excluded`, or `NotApplied` |
| UserPath | String | User-scope delivery path (e.g. `Include:<group>`, `AllLicensedUsers`, `Excluded:<group>`, `-`) |
| DevicePath | String | Device-scope delivery path (e.g. `Include:<group>`, `AllDevices`, `Excluded:<group>`, `-`) |
| FilterName | String | Semicolon-joined filter names from contributing rows |

## Examples

### Example 1 - Basic reverse lookup

```powershell
Get-LKGroupAssignment -Name 'SG-Intune-D-Pilot Devices' -NameMatch Exact
```

### Example 2 - Find scope mismatches

```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' | Where-Object ScopeMismatch
```

### Example 3 - Exclusions only

```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType Exclude
```

### Example 4 - Filter by policy type

```powershell
Get-LKGroupAssignment -Name 'Pilot' -PolicyType CompliancePolicy, SettingsCatalog
```

### Example 5 - App assignments with intent

```powershell
Get-LKGroupAssignment -Name 'All Users' -PolicyType App | Format-Table PolicyName, Intent
```

### Example 5b - Scan only Android apps (faster on app-heavy tenants)

```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' -NameMatch Exact -PolicyType App -Platform Android
```

### Example 6 - Joint effective assessment across user + device groups

```powershell
Get-LKGroupAssignment `
    -Name 'SG-Intune-U-Pilot Users','SG-Intune-D-Pilot Devices' `
    -NameMatch Exact `
    -Effective |
    Sort-Object EffectiveState, DisplayType, PolicyName |
    Format-Table DisplayType, PolicyName, EffectiveState, UserPath, DevicePath, FilterName -AutoSize
```

Answers: for a user in `SG-Intune-U-Pilot Users` whose device is in `SG-Intune-D-Pilot Devices`, which policies effectively apply? Excludes are evaluated per-scope — a user-group Exclude won't cancel the device's `AllDevices` delivery path, and vice versa.

### Example 7 - Only what actually hits the user + device

```powershell
Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users','SG-Intune-D-Pilot Devices' -NameMatch Exact -AppliedOnly |
    Sort-Object DisplayType, PolicyName |
    Format-Table DisplayType, PolicyName, UserPath, DevicePath, FilterName -AutoSize
```

Hides `Excluded` and `NotApplied` rows so you see only the policies that actually deliver. `-AppliedOnly` implies `-Effective`.

## Related

- [Get-LKGroup](Get-LKGroup.md)
- [Get-LKPolicyAssignment](../policies/Get-LKPolicyAssignment.md)
