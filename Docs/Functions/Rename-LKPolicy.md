# Rename-LKPolicy

## Synopsis
Renames an Intune policy.

## Syntax
```powershell
# Pipeline (default)
Rename-LKPolicy
    [-InputObject <PSCustomObject>]
    -NewName <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Rename-LKPolicy
    -PolicyId <String>
    -PolicyType <String>
    -NewName <String>
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description
Updates the display name of an Intune policy via a PATCH request to the appropriate Graph endpoint. The policy's name property varies by type and is automatically determined from the internal policy type configuration. Supports both pipeline input from `Get-LKPolicy` and direct lookup by policy ID and type.

## Parameters

### -InputObject
A policy object from `Get-LKPolicy`. Accepted from the pipeline.

| | |
|---|---|
| Type: | PSCustomObject |
| Default: | -- |
| Required: | No |
| Pipeline: | ByValue |

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

### -NewName
The new display name for the policy.

| | |
|---|---|
| Type: | String |
| Default: | -- |
| Required: | Yes |
| Pipeline: | No |

## Outputs
`PSCustomObject` with properties:
- **PolicyId** -- the policy's Graph object ID
- **PolicyType** -- normalised type key
- **OldName** -- the previous display name
- **NewName** -- the updated display name
- **Action** -- `Renamed`

## Examples

### Example 1
```powershell
Get-LKPolicy -Name "Old Policy Name" -NameMatch Exact | Rename-LKPolicy -NewName "New Policy Name"
```
Renames the policy with the exact name "Old Policy Name" to "New Policy Name".

### Example 2
```powershell
Rename-LKPolicy -PolicyId 'abc-123' -PolicyType SettingsCatalog -NewName "New Name"
```
Renames a specific Settings Catalog policy by its ID.

## Notes
- Requires an active session (`New-LKSession`).
- The correct name property for each policy type (e.g. `displayName`, `name`) is determined automatically from the internal type configuration.
- See also: `Get-LKPolicy`, `Rename-LKGroup`.
