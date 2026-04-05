# Get-LKGroupAssignment

## Synopsis
Finds all Intune policies where a specific group is assigned (included or excluded).

## Syntax
```powershell
# By name (default)
Get-LKGroupAssignment
    -Name <String[]>
    [-NameMatch <String>]        # 'Contains' (default) | 'Exact' | 'Wildcard' | 'Regex'
    [-PolicyType <String[]>]
    [-AssignmentType <String>]   # 'Include' (default) | 'Exclude' | 'All'
    [-SkipScopeResolution]
    [<CommonParameters>]

# By ID
Get-LKGroupAssignment
    -GroupId <String>
    [-PolicyType <String[]>]
    [-AssignmentType <String>]   # 'Include' (default) | 'Exclude' | 'All'
    [-SkipScopeResolution]
    [<CommonParameters>]
```

## Description
Performs a reverse lookup -- iterates across all configured policy types (or a specified subset), fetches each policy's assignments, and checks whether the specified group(s) appear as an include or exclude target. This is comprehensive but can be slow when scanning all types.

When using `-Name` with `-NameMatch Contains` (the default), multiple groups may match. All matching groups are scanned and results include the group name for each match. Use `-NameMatch Exact` to restrict to a single specific group.

Policies assigned to "All Devices" or "All Users" are included when they would effectively target the group, based on the group's member scope. If the group is explicitly excluded from such a policy, it is not shown as an implicit match.

Every result includes `PolicyScope`, `GroupScope`, and `ScopeMismatch` properties to help identify assignments where a device group is assigned to a user-scoped policy (or vice versa). Policy scope is automatically resolved via Graph metadata. Use `-SkipScopeResolution` to disable dynamic resolution for faster results (at the cost of `ScopeMismatch` being `$null` for "Both"-typed policies).

## Parameters

### -Name
One or more name patterns to match against group display names. Matching behaviour is controlled by `-NameMatch`.

| | |
|---|---|
| Type: | String[] |
| Default: | -- |
| Required: | Yes (ByName set) |
| Pipeline: | No |

### -NameMatch
Determines how `-Name` values are matched against group names.

| | |
|---|---|
| Type: | String |
| Default: | Contains |
| Required: | No |
| Pipeline: | No |
| Valid values: | Contains, Exact, Wildcard, Regex |

### -GroupId
The Entra ID object ID of the group.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (ById set) |
| Pipeline: | No |

### -PolicyType
Limits the scan to one or more specific policy types. If omitted, all types are scanned.

| | |
|---|---|
| Type: | String[] |
| Default: | -- (all types) |
| Required: | No |
| Pipeline: | No |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -AssignmentType
Controls which assignment types are returned. Defaults to `Include`, which shows only policies where the group is actively targeted (include assignments and broad targets like All Devices/All Users). Use `Exclude` to see only exclusions, or `All` to see everything.

| | |
|---|---|
| Type: | String |
| Default: | Include |
| Required: | No |
| Pipeline: | No |
| Valid values: | Include, Exclude, All |

### -SkipScopeResolution
Disables dynamic scope resolution for policy types with a static scope of "Both". When set, the static registry scope is used instead, which is faster but means `ScopeMismatch` will be `$null` for types like SettingsCatalog and DeviceConfiguration.

| | |
|---|---|
| Type: | Switch |
| Default: | False |
| Required: | No |
| Pipeline: | No |

## Outputs
`PSCustomObject` (type name `LKGroupAssignment`) with properties:
- **PolicyId** -- the policy's Graph object ID
- **PolicyName** -- display name of the policy
- **PolicyType** -- normalised type key (e.g. `SettingsCatalog`)
- **DisplayType** -- human-friendly policy type label
- **PolicyScope** -- the policy's target scope: `User`, `Device`, or `Both`. With `-ResolveScope`, dynamically resolved for "Both" types.
- **AssignmentType** -- one of:
  - `Include` -- the group is explicitly assigned
  - `Exclude` -- the group is explicitly excluded
  - `AllDevices` -- the policy targets all devices, which implicitly covers this group
  - `AllUsers` -- the policy targets all users, which implicitly covers this group
  - `AllLicensedUsers` -- the policy targets all licensed users, which implicitly covers this group
- **GroupId** -- the group's object ID
- **GroupName** -- the group's display name
- **GroupScope** -- the group's member scope: `User`, `Device`, `Both`, or `Unknown`
- **ScopeMismatch** -- `$true` if policy scope and group scope are incompatible (e.g. device group on user policy), `$false` if they match, `$null` if either scope is unknown or "Both"

## Examples

### Example 1
```powershell
Get-LKGroupAssignment -Name 'Pilot Devices'
```
Finds every Intune policy assigned to groups whose name contains "Pilot Devices".

### Example 2
```powershell
Get-LKGroupAssignment -Name 'XW365-Intune-D-Pilot Devices' -NameMatch Exact
```
Scans for policies assigned to the exact group, with automatic scope resolution and mismatch detection.

### Example 3
```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' | Where-Object ScopeMismatch
```
Shows only assignments where a scope mismatch is detected (e.g. a device group assigned to a user-scoped policy).

### Example 4
```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' | Where-Object { $_.ScopeMismatch -eq $false }
```
Shows only correctly scoped assignments.

### Example 5
```powershell
Get-LKGroupAssignment -Name 'SG-Intune-*' -NameMatch Wildcard -PolicyType CompliancePolicy
```
Scans only Compliance policies for assignments to groups matching the wildcard pattern.

### Example 6
```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType Exclude
```
Shows only policies where the group is excluded.

### Example 7
```powershell
Get-LKGroupAssignment -Name 'Pilot Devices' -AssignmentType All
```
Shows both include and exclude assignments for the group.

### Example 8
```powershell
Get-LKGroupAssignment -GroupId 'abc-123' -PolicyType CompliancePolicy, SettingsCatalog
```
Scans only Compliance and Settings Catalog policies for assignments referencing the given group ID.

## Notes
- Requires an active session (`New-LKSession`).
- Scanning all policy types requires one API call per policy type plus one call per policy to fetch assignments, so it can be slow for large tenants. Use `-PolicyType` to narrow the scope.
- When multiple groups match, all are scanned and the `GroupName` column identifies which group each result belongs to.
- Policies assigned to "All Devices" or "All Users" are included when they would implicitly target the group, based on the group's member scope. If the group is explicitly excluded from such a policy, it is not shown as an `AllDevices`/`AllUsers` match.
- Scope resolution is on by default and adds ~1 API call per matching SettingsCatalog/GroupPolicyConfiguration policy. EndpointSecurity templates are cached. Use `-SkipScopeResolution` if you need speed over accuracy.
- See also: `Get-LKPolicyAssignment`, `Get-LKPolicy`.
