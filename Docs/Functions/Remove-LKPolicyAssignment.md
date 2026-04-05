# Remove-LKPolicyAssignment

## Synopsis
Removes a group include assignment from one or more Intune policies.

## Syntax
```powershell
# By name (default)
Remove-LKPolicyAssignment
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Remove-LKPolicyAssignment
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Remove-LKPolicyAssignment
    -GroupName <String>
    -PolicyId <String>
    -PolicyType <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
For each target policy, fetches the current assignments, removes the group include entry for the specified group, and writes back the updated assignment set. Policies where the group is not currently assigned are silently skipped. Supports `-WhatIf` and `-Confirm` for safe previewing.

The target policy can be found by name, received from pipeline input, or specified directly by ID and type.

## Parameters

### -GroupName
The exact display name of the Entra ID group whose include assignment should be removed.

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

### -PolicyId
The Graph object ID of the policy. Required when using the `ById` parameter set.

| | |
|---|---|
| Type: | String |
| Required: | Yes (ById set) |

### -PolicyType
The normalised policy type key. Required when using the `ById` parameter set.

| | |
|---|---|
| Type: | String |
| Required: | Yes (ById set) |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

## Outputs
`PSCustomObject` per modified policy with properties:
- **PolicyName** -- name of the modified policy
- **PolicyType** -- normalised type key
- **Action** -- `AssignmentRemoved`
- **GroupName** -- the group's display name
- **GroupId** -- the group's object ID

## Examples

### Example 1 -- Remove by policy name
```powershell
Remove-LKPolicyAssignment -PolicyName "XW365 - Win - SC - Microsoft Edge - U - Extensions" -NameMatch Exact -GroupName 'XW365-Intune-D-Pilot Devices'
```
Removes the device group from a user-scoped Edge extensions policy.

### Example 2 -- Fix mismatches from audit
```powershell
$mismatches = Test-LKPolicyAssignment -PolicyType SettingsCatalog | Where-Object Severity -eq 'Mismatch'
foreach ($m in $mismatches) {
    Remove-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact -GroupName $m.GroupName
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact -GroupName 'XW365-Intune-U-Pilot Users'
}
```
Removes incorrect assignments and replaces them with the correctly-scoped group.

### Example 3 -- Pipeline from Get-LKPolicy
```powershell
Get-LKPolicy -Name "XW365 - TestConfig" | Remove-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
```
Removes the group from all policies whose name contains "XW365 - TestConfig".

### Example 4 -- By policy ID
```powershell
Remove-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
```
Removes the group assignment from a specific Settings Catalog policy by its ID.

## Notes
- Requires an active session (`New-LKSession`).
- Only removes include assignments, not exclusions. To remove an exclusion, use `Remove-LKPolicyExclusion`.
- Policies where the group is not assigned are skipped with a verbose message.
- See also: `Add-LKPolicyAssignment`, `Remove-LKPolicyExclusion`, `Test-LKPolicyAssignment`.
