# Remove-LKPolicyExclusion

## Synopsis
Removes a group exclusion from one or more Intune policies.

## Syntax
```powershell
# By name (default)
Remove-LKPolicyExclusion
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Remove-LKPolicyExclusion
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# All policies
Remove-LKPolicyExclusion
    -GroupName <String>
    -All
    [-PolicyType <String[]>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
For each target policy, fetches the current assignments, removes the exclusion entry for the specified group, and writes back the updated assignment set. Policies where the group is not currently excluded are silently skipped. Supports `-WhatIf` and `-Confirm` for safe previewing.

The target policies can be found by name, received from pipeline input, or the `-All` switch, optionally filtered by `-PolicyType`.

## Parameters

### -GroupName
The exact display name of the Entra ID group whose exclusion should be removed.

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
- **Action** -- `ExclusionRemoved`
- **GroupName** -- the group's display name
- **GroupId** -- the group's object ID

## Examples

### Example 1 -- Remove exclusion by policy name
```powershell
Remove-LKPolicyExclusion -PolicyName "XW365 - Win - SC - Microsoft Edge" -GroupName 'XW365-Intune-D-Pilot Devices'
```
Removes the device group exclusion from all Edge policies.

### Example 2 -- Remove exclusion from all policies
```powershell
Remove-LKPolicyExclusion -GroupName 'SG-Intune-TestDevices' -All
```
Removes the exclusion for "SG-Intune-TestDevices" from every policy that currently excludes it.

### Example 3 -- Pipeline from Get-LKPolicy
```powershell
Get-LKPolicy -Name "XW365" | Remove-LKPolicyExclusion -GroupName 'TestGroup'
```
Removes the exclusion from policies whose name contains "XW365".

## Notes
- Requires an active session (`New-LKSession`).
- Policies where the group is not excluded are skipped with a verbose message.
- See also: `Add-LKPolicyExclusion`, `Remove-LKPolicyAssignment`, `Test-LKPolicyAssignment`.
