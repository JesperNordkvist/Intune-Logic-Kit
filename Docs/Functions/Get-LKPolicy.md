# Get-LKPolicy

## Synopsis
Queries Intune policies across all or specific policy types with flexible name filtering.

## Syntax
```powershell
Get-LKPolicy
    [-Name <String[]>]
    [-NameMatch <String>]         # 'Contains' (default) | 'Exact' | 'Wildcard' | 'Regex'
    [-PolicyType <String[]>]
    [-ResolveScope]
    [-IncludeSettings]
    [-FilterScript <ScriptBlock>]
    [<CommonParameters>]
```

## Description
Iterates over all configured Intune policy types (or a specified subset) and returns normalised policy objects that match the given name filter. Each policy type is queried via its dedicated Graph endpoint. Progress is displayed as each type is scanned.

Filtering happens in two stages: server-side where the API supports it, and client-side via `Test-LKNameMatch` for wildcard, regex, or multi-value patterns. An optional `FilterScript` provides arbitrary post-filter logic.

## Parameters

### -Name
One or more name strings to match against the policy display name. Matching behaviour is controlled by `-NameMatch`.

| | |
|---|---|
| Type: | String[] |
| Default: | -- |
| Required: | No |
| Pipeline: | No |

### -NameMatch
Determines how `-Name` values are matched.

| | |
|---|---|
| Type: | String |
| Default: | Contains |
| Required: | No |
| Pipeline: | No |
| Valid values: | Contains, Exact, Wildcard, Regex |

### -PolicyType
Limits the query to one or more specific policy types instead of scanning all types.

| | |
|---|---|
| Type: | String[] |
| Default: | -- (all types) |
| Required: | No |
| Pipeline: | No |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -ResolveScope
When specified, performs additional Graph API calls to determine the accurate User/Device scope of each policy. Without this switch, the scope falls back to the static value from the policy type registry (often `Both`).

| | |
|---|---|
| Type: | Switch |
| Default: | False |
| Required: | No |
| Pipeline: | No |

### -IncludeSettings
When specified, fetches the configured settings for each policy and attaches them as a `Settings` property on the output object. Each setting is a hashtable with `Name`, `Value`, and `Category` keys.

| | |
|---|---|
| Type: | Switch |
| Default: | False |
| Required: | No |
| Pipeline: | No |

### -FilterScript
A script block applied to each normalised policy object. Only objects where the script block returns `$true` are emitted.

| | |
|---|---|
| Type: | ScriptBlock |
| Default: | -- |
| Required: | No |
| Pipeline: | No |

## Outputs
`PSCustomObject` (type name `LKPolicy`) with properties:
- **Id** -- the policy's Graph object ID
- **Name** -- the policy display name
- **PolicyType** -- the normalised type key (e.g. `SettingsCatalog`)
- **DisplayType** -- human-readable type label
- **Description** -- policy description
- **TargetScope** -- User, Device, or Both
- **CreatedAt** -- creation timestamp
- **ModifiedAt** -- last modified timestamp
- **RawObject** -- the original Graph API response object
- **Settings** -- (only with `-IncludeSettings`) array of settings hashtables

## Examples

### Example 1
```powershell
Get-LKPolicy -Name "XW365" -NameMatch Contains
```
Returns all policies whose name contains "XW365", across every policy type.

### Example 2
```powershell
Get-LKPolicy -PolicyType SettingsCatalog, CompliancePolicy
```
Returns all Settings Catalog and Compliance policies regardless of name.

### Example 3
```powershell
Get-LKPolicy -Name "Baseline*" -NameMatch Wildcard -FilterScript { $_.TargetScope -eq 'Device' }
```
Returns policies matching the wildcard pattern "Baseline*" that are device-scoped.

### Example 4
```powershell
Get-LKPolicy -ResolveScope
```
Returns all policies with accurate User/Device scope resolved via Graph metadata.

### Example 5
```powershell
Get-LKPolicy -Name "Firewall" -IncludeSettings
```
Returns firewall policies with their configured settings attached. Access with `$policy.Settings`.

### Example 6
```powershell
Get-LKPolicy -Name "Baseline" | Show-LKPolicyDetail
```
Displays a rich formatted view of each matching policy, including all settings and assignments.

## Notes
- Requires an active session (`New-LKSession`).
- Querying all policy types can take a while; narrow with `-PolicyType` for faster results.
- `-IncludeSettings` adds extra API calls per policy; combine with `-Name` or `-PolicyType` for best performance.
- Output objects can be piped to `Show-LKPolicyDetail`, `Get-LKPolicyAssignment`, `Add-LKPolicyExclusion`, `Remove-LKPolicyExclusion`, `Add-LKPolicyAssignment`, `Remove-LKPolicyAssignment`, and `Rename-LKPolicy`.
