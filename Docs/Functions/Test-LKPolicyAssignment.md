# Test-LKPolicyAssignment

## Synopsis
Audits Intune policies for scope mismatches -- device policies assigned to user groups (or vice versa).

## Syntax
```powershell
Test-LKPolicyAssignment
    [-PolicyType <String[]>]
    [-Name <String[]>]
    [-NameMatch <String>]
    [-Detailed]
    [<CommonParameters>]
```

## Description
Iterates all (or filtered) policy types, resolves each policy's effective scope (User/Device/Both), fetches assignments, determines each assigned group's scope via transitive membership (including nested groups), and flags mismatches for review.

**Severity levels:**
- **Mismatch** -- Wrong scope. A user-scoped policy assigned to a device group, or a device-scoped policy assigned to a user group. The policy will not apply correctly.
- **Warning** -- Mixed-scope group. The group contains both users and devices; the policy may partially apply.
- **Info** -- Unresolved. The group is empty or its scope could not be determined. Manual review recommended.

Group scope results are cached per session to avoid redundant Graph API calls when the same group appears across multiple policies.

## Parameters

### -PolicyType
Limits the audit to one or more specific policy types.

| | |
|---|---|
| Type: | String[] |
| Default: | All types |
| Valid values: | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -Name
One or more policy name patterns to filter on.

| | |
|---|---|
| Type: | String[] |
| Default: | -- (all policies) |

### -NameMatch
How `-Name` is matched. Default: `Contains`.

| | |
|---|---|
| Type: | String |
| Default: | Contains |
| Valid values: | Contains, Exact, Wildcard, Regex |

### -Detailed
Renders a formatted, color-coded summary grouped by severity. The objects are still emitted to the pipeline for capture.

| | |
|---|---|
| Type: | SwitchParameter |
| Default: | False |

## Outputs
`LKPolicyAssignmentIssue` objects with properties:
- **PolicyId** -- Graph object ID of the policy
- **PolicyName** -- display name of the policy
- **PolicyType** -- display name of the policy type
- **PolicyTypeId** -- normalised type key (usable with `-PolicyType` parameters)
- **PolicyScope** -- resolved scope: User, Device, or Both
- **AssignmentType** -- Include, Exclude, AllDevices, AllUsers, or AllLicensedUsers
- **GroupName** -- display name of the assigned group (or broad target label)
- **GroupScope** -- resolved scope of the group: User, Device, Both, or Unknown
- **DeviceCount** -- number of devices in the group (transitive)
- **UserCount** -- number of users in the group (transitive)
- **Severity** -- Mismatch, Warning, or Info
- **Detail** -- human-readable explanation of the issue

## Examples

### Example 1 -- Full audit with formatted output
```powershell
Test-LKPolicyAssignment -Detailed
```
Audits all policy types and displays a color-coded summary of mismatches, warnings, and unresolved groups.

### Example 2 -- Audit only Settings Catalog
```powershell
Test-LKPolicyAssignment -PolicyType SettingsCatalog -Detailed
```
Limits the audit to Settings Catalog policies for faster results.

### Example 3 -- Find mismatches and fix them
```powershell
$mismatches = Test-LKPolicyAssignment | Where-Object { $_.Severity -eq 'Mismatch' -and $_.AssignmentType -eq 'Include' }
foreach ($m in $mismatches) {
    # Pick the correct replacement group based on what the policy needs
    $correctGroup = if ($m.PolicyScope -eq 'Device') {
        'XW365-Intune-D-Pilot Devices'
    } else {
        'XW365-Intune-U-Pilot Users'
    }
    Remove-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $m.GroupName -Confirm:$false
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $correctGroup -Confirm:$false
}
```
Finds mismatched include assignments, removes them, and adds the correct-scope group. Branches on `PolicyScope` to avoid swapping a wrong group for another wrong group.

### Example 4 -- Filter to specific policies
```powershell
Test-LKPolicyAssignment -Name "XW365 - Win - SC - Microsoft Edge" -Detailed
```
Audits only Edge-related policies.

### Example 5 -- Export to CSV for review
```powershell
Test-LKPolicyAssignment | Where-Object Severity -ne 'Info' | Export-Csv -Path .\audit-results.csv -NoTypeInformation
```
Exports mismatches and warnings (excluding unresolved) to a CSV file.

### Example 6 -- Fix exclusion mismatches
```powershell
$badExclusions = Test-LKPolicyAssignment | Where-Object { $_.Severity -eq 'Mismatch' -and $_.AssignmentType -eq 'Exclude' }
foreach ($m in $badExclusions) {
    $correctGroup = if ($m.PolicyScope -eq 'Device') { 'XW365-Intune-D-Pilot Devices' } else { 'XW365-Intune-U-Pilot Users' }
    Remove-LKPolicyExclusion -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $m.GroupName -Confirm:$false
    Add-LKPolicyExclusion -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $correctGroup -Confirm:$false
}
```
Same pattern as Example 3 but for exclusion assignments -- uses `AssignmentType` to know whether to call the Assignment or Exclusion functions.

## How Scope Resolution Works

### Policy Scope
- **Static scope**: Some policy types have a fixed scope (e.g. PowerShell Scripts are always Device, App Protection is always User).
- **Dynamic resolution**: For Settings Catalog, the first setting's definition ID prefix (`device_*` or `user_*`) determines scope. For ADMX policies, the definition's `classType` (user/machine) is checked. For Endpoint Security, the template type/subtype is inspected.
- **Both**: If scope cannot be narrowed, the policy is treated as `Both` and excluded from mismatch checks.

### Group Scope
- **Dynamic groups**: The membership rule is parsed (fast path -- no API calls for members).
- **Assigned groups**: Transitive members are enumerated via `/groups/{id}/transitiveMembers`, which recursively expands nested groups. Members are counted by type (device vs user).
- **Empty groups**: Reported as `Unknown` / `Info` severity for manual review.

## Notes
- Requires an active session (`New-LKSession`).
- Policies with `Both` scope are excluded from the audit (they can't have a mismatch).
- Group scope is cached for the duration of the command -- the same group is only resolved once even if it appears in hundreds of policies.
- See also: `Add-LKPolicyAssignment`, `Remove-LKPolicyAssignment`, `Get-LKGroupAssignment`.
