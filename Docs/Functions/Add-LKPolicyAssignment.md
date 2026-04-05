# Add-LKPolicyAssignment

## Synopsis
Adds a group as an include assignment to one or more Intune policies.

## Syntax
```powershell
# By name (default)
Add-LKPolicyAssignment
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Add-LKPolicyAssignment
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Add-LKPolicyAssignment
    -GroupName <String>
    -PolicyId <String>
    -PolicyType <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
For each target policy, fetches the current assignments, appends a group include entry, and writes back the complete assignment set using a replace-all pattern. Policies that already include the group are silently skipped. Supports `-WhatIf` and `-Confirm` for safe previewing.

The target policy can be found by name, received from pipeline input (e.g. from `Get-LKPolicy`), or specified directly by ID and type.

## Parameters

### -GroupName
The exact display name of the Entra ID group to assign to the policy.

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
- **Action** -- `AssignmentAdded`
- **GroupName** -- the assigned group's display name
- **GroupId** -- the assigned group's object ID

## Examples

### Example 1 -- Assign by policy name
```powershell
Add-LKPolicyAssignment -PolicyName "XW365 - Win - SC - Microsoft Edge - U - Extensions" -NameMatch Exact -GroupName 'XW365-Intune-U-Pilot Users'
```
Assigns the user pilot group to a specific Edge extensions policy.

### Example 2 -- Assign to all matching policies
```powershell
Add-LKPolicyAssignment -PolicyName "XW365 - Win - SC - Microsoft Edge - U" -GroupName 'XW365-Intune-U-Pilot Users'
```
Assigns the group to all user-scoped Edge policies (contains match).

### Example 3 -- Fix mismatches from audit
```powershell
$mismatches = Test-LKPolicyAssignment -PolicyType SettingsCatalog | Where-Object Severity -eq 'Mismatch'
foreach ($m in $mismatches) {
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact -GroupName 'XW365-Intune-U-Pilot Users'
}
```
Uses `Test-LKPolicyAssignment` to find scope mismatches and re-assigns them to the correct group.

### Example 4 -- Pipeline from Get-LKPolicy
```powershell
Get-LKPolicy -Name "XW365 - TestConfig" | Add-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
```
Assigns the group to all policies whose name contains "XW365 - TestConfig".

### Example 5 -- By policy ID
```powershell
Add-LKPolicyAssignment -GroupName 'TestDevices' -PolicyId 'abc-123' -PolicyType SettingsCatalog
```
Assigns the group to a specific Settings Catalog policy by its ID.

## Notes
- Requires an active session (`New-LKSession`).
- Policies where the group is already included are skipped with a verbose message.
- Performs a scope mismatch check: if the group scope is incompatible with the policy scope, the assignment is skipped with a warning.
- This adds a group include (not an exclusion). To add an exclusion, use `Add-LKPolicyExclusion`.
- See also: `Remove-LKPolicyAssignment`, `Add-LKPolicyExclusion`, `Test-LKPolicyAssignment`.
