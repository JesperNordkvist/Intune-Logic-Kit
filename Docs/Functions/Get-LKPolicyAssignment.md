# Get-LKPolicyAssignment

## Synopsis
Shows the assignment details (includes, excludes) for one or more policies.

## Syntax
```powershell
# Pipeline (default)
Get-LKPolicyAssignment
    [-InputObject <PSCustomObject>]
    [<CommonParameters>]

# By ID
Get-LKPolicyAssignment
    -PolicyId <String>
    -PolicyType <String>
    [<CommonParameters>]
```

## Description
Fetches the assignment targets for one or more Intune policies and resolves each target to a human-readable form. Each assignment entry indicates whether a group is included, excluded, or whether the policy targets all devices, all users, or all licensed users. Group display names are resolved and cached for the duration of the pipeline.

Supports both pipeline input from `Get-LKPolicy` and direct lookup by policy ID and type.

## Parameters

### -PolicyId
The Graph object ID of the policy. Required when using the `ById` parameter set.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (ById set) |
| Pipeline: | No |

### -PolicyType
The normalised policy type key. Required when using the `ById` parameter set.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes (ById set) |
| Pipeline: | No |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -InputObject
A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| | |
|---|---|
| Type: | PSCustomObject |
| Default: | -- |
| Required: | No |
| Pipeline: | ByValue |

## Outputs
`PSCustomObject` (type name `LKPolicyAssignment`) with properties:
- **PolicyId** -- the policy's Graph object ID
- **PolicyName** -- display name of the policy
- **PolicyType** -- normalised type key
- **AssignmentType** -- one of `Include`, `Exclude`, `AllDevices`, `AllUsers`, `AllLicensedUsers`, or `Unknown`
- **GroupId** -- the target group's object ID (null for AllDevices/AllUsers targets)
- **GroupName** -- resolved display name of the group
- **Intent** -- the assignment intent value from Graph (if present)

## Examples

### Example 1
```powershell
Get-LKPolicy -Name "XW365" | Get-LKPolicyAssignment
```
Lists every assignment (includes and excludes) for all policies whose name contains "XW365".

### Example 2
```powershell
Get-LKPolicyAssignment -PolicyId 'abc-123' -PolicyType SettingsCatalog
```
Returns the assignments for a specific Settings Catalog policy identified by its ID.

## Notes
- Requires an active session (`New-LKSession`).
- Group names are cached within a single pipeline execution to reduce Graph API calls.
- See also: `Get-LKPolicy`, `Get-LKGroupAssignment`.
