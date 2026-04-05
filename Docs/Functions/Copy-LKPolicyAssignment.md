# Copy-LKPolicyAssignment

## Synopsis
Copies all assignments from a source policy to one or more target policies.

## Syntax
```powershell
# Pipeline targets with source object
Copy-LKPolicyAssignment
    -SourcePolicy <PSCustomObject>
    [-InputObject <PSCustomObject>]
    [-Mode <String>]             # 'Replace' (default) | 'Merge'
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Explicit target with source object
Copy-LKPolicyAssignment
    -SourcePolicy <PSCustomObject>
    -TargetPolicyId <String>
    -TargetPolicyType <String>
    [-Mode <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# All explicit IDs
Copy-LKPolicyAssignment
    -SourcePolicyId <String>
    -SourcePolicyType <String>
    -TargetPolicyId <String>
    -TargetPolicyType <String>
    [-Mode <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
Copies all assignments (includes and exclusions) from a source policy to one or more target policies. The source assignments are fetched once and applied to each target. In Replace mode, the target's existing assignments are overwritten. In Merge mode, source assignments are added alongside existing target assignments (duplicates are skipped).

## Parameters

### -SourcePolicy
A policy object from `Get-LKPolicy` to use as the assignment source.

| | |
|---|---|
| Type: | PSCustomObject |
| Default: | -- |
| Required: | Yes (ByPipeline and ByTargetId sets) |
| Pipeline: | No |

### -SourcePolicyId
The ID of the source policy. Used with `-SourcePolicyType` when a policy object is not available.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (BySourceId set) |
| Pipeline: | No |

### -SourcePolicyType
The type of the source policy.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (BySourceId set) |
| Pipeline: | No |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -InputObject
A policy object from `Get-LKPolicy` to use as the target. Accepted from the pipeline for bulk operations.

| | |
|---|---|
| Type: | PSCustomObject |
| Default: | -- |
| Required: | No |
| Pipeline: | ByValue |

### -TargetPolicyId
The ID of the target policy.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (ByTargetId and BySourceId sets) |
| Pipeline: | No |

### -TargetPolicyType
The type of the target policy.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (ByTargetId and BySourceId sets) |
| Pipeline: | No |
| Valid values: | (same as SourcePolicyType) |

### -Mode
How to apply the assignments to the target.

| | |
|---|---|
| Type: | String |
| Default: | Replace |
| Required: | No |
| Pipeline: | No |
| Valid values: | Replace, Merge |

| Mode | Behaviour |
|------|-----------|
| Replace | Overwrites the target's existing assignments entirely |
| Merge | Adds source assignments while keeping existing target assignments. Duplicates (same group + same assignment type) are skipped. |

## Outputs
`PSCustomObject` with properties:
- **SourcePolicy** -- the source policy's name
- **TargetPolicy** -- the target policy's name
- **AssignmentsCopied** -- the number of assignments from the source
- **Mode** -- `Replace` or `Merge`
- **Action** -- `AssignmentsCopied`

## Examples

### Example 1
```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Get-LKPolicy -Name "XW365*" -NameMatch Wildcard | Copy-LKPolicyAssignment -SourcePolicy $source
```
Copies assignments from "Reference Policy" to all policies matching "XW365*".

### Example 2
```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Copy-LKPolicyAssignment -SourcePolicy $source -TargetPolicyId 'def-456' -TargetPolicyType CompliancePolicy
```
Copies assignments to a specific policy by ID.

### Example 3
```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Get-LKPolicy -Name "XW365*" | Copy-LKPolicyAssignment -SourcePolicy $source -Mode Merge
```
Merges source assignments into each target's existing assignments.

### Example 4
```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Get-LKPolicy -Name "XW365*" | Copy-LKPolicyAssignment -SourcePolicy $source -WhatIf
```
Previews the copy operation without making changes.

## Notes
- Requires an active session (`New-LKSession`).
- Source assignments are fetched once in the `begin` block for efficiency when piping multiple targets.
- Copying between policies with different assignment methods (Standard vs GroupAssignments) is not supported and will display a warning.
- Self-copy (source and target are the same policy) is detected and skipped.
- See also: `Get-LKPolicy`, `Get-LKPolicyAssignment`, `Add-LKPolicyAssignment`.
