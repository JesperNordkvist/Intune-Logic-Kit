---
title: Add-LKPolicyAssignment
nav_order: 3
---

# Add-LKPolicyAssignment

Adds a group as an include assignment to one or more Intune policies.

## Syntax

```text
# By name (default)
Add-LKPolicyAssignment
    -GroupName <String>
    -PolicyName <String[]>
    [-NameMatch <String>]
    [-SearchPolicyType <String[]>]
    [-Intent <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# Pipeline
Add-LKPolicyAssignment
    -GroupName <String>
    [-InputObject <PSCustomObject>]
    [-Intent <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By ID
Add-LKPolicyAssignment
    -GroupName <String>
    -PolicyId <String>
    [-PolicyType <String>]
    [-Intent <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

For each target policy, fetches the current assignments, appends a group include entry, and writes back the complete assignment set. Policies that already include the group are silently skipped. Performs a scope mismatch check - if the group scope is incompatible with the policy scope, the assignment is skipped with a warning.

## Parameters

### -GroupName

The exact display name of the Entra ID group to assign.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -PolicyName

One or more policy name patterns.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | Yes (ByName) |

### -NameMatch

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Contains |
| Valid values | Contains, Exact, Wildcard, Regex |

### -SearchPolicyType

Restrict the policy name search to specific types.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |
| Valid values | DeviceConfiguration, SettingsCatalog, CompliancePolicy, EndpointSecurity, AppProtectionIOS, AppProtectionAndroid, AppProtectionWindows, AppConfiguration, EnrollmentConfiguration, PolicySet, GroupPolicyConfiguration, PlatformScript, Remediation, DriverUpdate, App |

### -InputObject

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -PolicyId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ById) |

### -PolicyType

Optional - auto-resolved if omitted.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -Intent

The deployment intent for app assignments. Only applies to App policy type.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |
| Valid values | Required, Available, Uninstall |

## Outputs

| Property | Type | Description |
|---|---|---|
| PolicyName | String | Modified policy name |
| PolicyType | String | Normalised type key |
| Action | String | `AssignmentAdded` |
| GroupName | String | Assigned group name |
| GroupId | String | Assigned group GUID |

## Examples

### Example 1 - By policy name

```powershell
Add-LKPolicyAssignment -PolicyName "Contoso - Win - SC - Microsoft Edge" -GroupName 'SG-Intune-U-Pilot Users'
```

### Example 2 - Pipeline from Get-LKPolicy

```powershell
Get-LKPolicy -Name "Contoso - TestConfig" | Add-LKPolicyAssignment -GroupName 'SG-Intune-TestDevices'
```

### Example 3 - App as Required

```powershell
Get-LKPolicy -Name "Google Chrome" -PolicyType App | Add-LKPolicyAssignment -GroupName 'All Users' -Intent Required
```

### Example 4 - Fix audit mismatches

```powershell
$mismatches = Test-LKPolicyAssignment | Where-Object Severity -eq 'Mismatch'
foreach ($m in $mismatches) {
    Remove-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $m.GroupName -Confirm:$false
    $correctGroup = if ($m.PolicyScope -eq 'Device') {
        "SG-Intune-D-Pilot Devices"
    } else {
        "SG-Intune-U-Pilot Users"
    }
    Add-LKPolicyAssignment -PolicyName $m.PolicyName -NameMatch Exact `
        -SearchPolicyType $m.PolicyTypeId -GroupName $correctGroup -Confirm:$false
}
```

## Notes

- Performs a scope mismatch check before assigning.
- To add an exclusion instead, use [Add-LKPolicyExclusion](Add-LKPolicyExclusion.md).

## Related

- [Remove-LKPolicyAssignment](Remove-LKPolicyAssignment.md)
- [Add-LKPolicyExclusion](Add-LKPolicyExclusion.md)
- [Test-LKPolicyAssignment](Test-LKPolicyAssignment.md)
