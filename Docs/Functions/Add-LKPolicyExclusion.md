# Add-LKPolicyExclusion

## Synopsis
Adds a group as an exclusion to one or more Intune policies.

## Syntax
```powershell
# By name (default)
Add-LKPolicyExclusion
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Add-LKPolicyExclusion
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# All policies
Add-LKPolicyExclusion
    -GroupName <String>
    -All
    [-PolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
For each target policy, fetches the current assignments, appends an exclusion entry for the specified group, and writes back the complete assignment set using a replace-all pattern. Policies that already exclude the group are silently skipped. Supports `-WhatIf` and `-Confirm` for safe previewing.

The target policies can be found by name, received from pipeline input (e.g. from `Get-LKPolicy`), or the `-All` switch can target every policy, optionally filtered by `-PolicyType`.

## Parameters

### -GroupName
The exact display name of the Entra ID group to add as an exclusion.

| | |
|---|---|
| Type: | String |
| Required: | Yes |

### -PolicyName
One or more policy name patterns to match. Uses `-NameMatch` to control matching behaviour.

| | |
|---|---|
| Type: | String[] |
| Required: | Yes (ByName set) |

### -NameMatch
How `-PolicyName` is matched. Default: `Contains`.

| | |
|---|---|
| Type: | String |
| Default: | Contains |
| Valid values: | Contains, Exact, Wildcard, Regex |

### -InputObject
A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| | |
|---|---|
| Type: | PSCustomObject |
| Pipeline: | ByValue |

### -All
Targets all Intune policies. Can be narrowed with `-PolicyType`.

| | |
|---|---|
| Type: | SwitchParameter |
| Required: | Yes (All set) |

### -PolicyType
When used with `-All`, limits the operation to one or more specific policy types.

| | |
|---|---|
| Type: | String[] |
| Default: | -- (all types) |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

## Outputs
`PSCustomObject` per modified policy with properties:
- **PolicyName** -- name of the modified policy
- **PolicyType** -- normalised type key
- **Action** -- `ExclusionAdded`
- **GroupName** -- the excluded group's display name
- **GroupId** -- the excluded group's object ID

## Examples

### Example 1 -- Exclude a device group from user-scoped policies by name
```powershell
Add-LKPolicyExclusion -PolicyName "- U -" -GroupName 'XW365-Intune-D-Pilot Devices'
```
Excludes a device group from all policies containing "- U -" in the name (user-scoped by naming convention).

### Example 2 -- Exclude from all policies of a specific type
```powershell
Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All -PolicyType CompliancePolicy
```
Adds the exclusion only to Compliance policies.

### Example 3 -- Exclude from all policies
```powershell
Add-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
```
Adds the group as an exclusion on every Intune policy.

### Example 4 -- Pipeline from Get-LKPolicy
```powershell
Get-LKPolicy -Name "XW365" | Add-LKPolicyExclusion -GroupName 'TestGroup'
```
Adds the exclusion to all policies whose name contains "XW365".

### Example 5 -- Preview changes
```powershell
Add-LKPolicyExclusion -PolicyName "Baseline*" -NameMatch Wildcard -GroupName 'TestGroup' -WhatIf
```
Previews which policies would be modified without making any changes.

## Notes
- Requires an active session (`New-LKSession`).
- Uses the replace-all assignment pattern: the entire assignment array is read, modified, and written back.
- Policies that already exclude the group are skipped with a verbose message.
- Performs a scope mismatch check: if the group scope is incompatible with the policy scope, the exclusion is skipped with a warning.
- See also: `Remove-LKPolicyExclusion`, `Add-LKPolicyAssignment`, `Test-LKPolicyAssignment`.
