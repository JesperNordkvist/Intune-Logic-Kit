# Show-LKPolicyDetail

## Synopsis
Displays a detailed, formatted view of Intune policies including all configured settings and assignments.

## Syntax
```powershell
# Pipeline (from Get-LKPolicy)
Get-LKPolicy ... | Show-LKPolicyDetail

# By ID
Show-LKPolicyDetail
    -PolicyId <String>
    -PolicyType <String>
```

## Description
Fetches the full settings and assignments for each policy and renders them in a readable, color-coded format grouped by category. This is the best way to see everything a policy configures at a glance.

Settings are fetched differently depending on policy type:
- **Settings Catalog** -- reads from the `/settings` sub-resource and recursively expands all setting instances
- **Endpoint Security** -- reads category-based settings from `/categories/.../settings`
- **Group Policy (ADMX)** -- reads definition values with expanded definitions
- **All other types** -- flattens the raw policy object properties into name/value pairs

## Parameters

### -InputObject
An LKPolicy object from `Get-LKPolicy`. Accepts pipeline input.

| | |
|---|---|
| Type: | PSCustomObject |
| Required: | Yes (pipeline set) |
| Pipeline: | Yes |

### -PolicyId
The Graph object ID of the policy.

| | |
|---|---|
| Type: | String |
| Required: | Yes (ById set) |
| Pipeline: | No |

### -PolicyType
The policy type key (must match a registered type).

| | |
|---|---|
| Type: | String |
| Required: | Yes (ById set) |
| Pipeline: | No |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

## Examples

### Example 1
```powershell
Get-LKPolicy -Name "XW365 - Baseline" | Show-LKPolicyDetail
```
Shows a formatted detail view of each policy matching "XW365 - Baseline", including all configured settings and group assignments.

### Example 2
```powershell
Get-LKPolicy -PolicyType SettingsCatalog -Name "Firewall" | Show-LKPolicyDetail
```
Shows detailed settings for all Settings Catalog policies containing "Firewall".

### Example 3
```powershell
Show-LKPolicyDetail -PolicyId 'abc-123' -PolicyType SettingsCatalog
```
Shows details for a specific policy by ID.

## Output Format
```
──────────────────────────────────────────────────────────────────────
  XW365 - Firewall Policy
──────────────────────────────────────────────────────────────────────
  Type         Settings Catalog Policy
  Scope        Device
  Created      2025-01-15T10:30:00Z
  Modified     2025-03-20T14:15:00Z

  ASSIGNMENTS
    [Include] SG-Intune-AllDevices
    [Exclude] SG-Intune-TestDevices

  SETTINGS
    vendor msft firewall mdmstore global enablepacketqueue  disabled
    vendor msft firewall mdmstore domainprofile enablefirewall  true
    ...
──────────────────────────────────────────────────────────────────────
```

## Notes
- Requires an active session (`New-LKSession`).
- Output is written to the host (not the pipeline) for formatted display.
- For programmatic access to settings, use `Get-LKPolicy -IncludeSettings` instead.
