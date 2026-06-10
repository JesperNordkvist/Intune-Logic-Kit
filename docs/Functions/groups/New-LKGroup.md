---
title: New-LKGroup
nav_order: 18
---

# New-LKGroup

Creates a new Entra ID security group (assigned or dynamic) for Intune.

## Syntax

```text
New-LKGroup
    -Name <String>
    [-Description <String>]
    [-GroupType <String>]
    [-MembershipRule <String>]
    [-MembershipRuleProcessingState <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

Creates a security group in Entra ID.

- **`-GroupType Assigned`** (default) - a static group. Add members later with `Add-LKGroupMember`.
- **`-GroupType Dynamic`** - requires `-MembershipRule`. Entra classifies the group as dynamic user or dynamic device automatically based on whether the rule uses `user.*` or `device.*` properties. No separate "dynamic user" / "dynamic device" switch is needed.

Dynamic groups require an Entra ID P1 license in the tenant.

## Parameters

### -Name

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -Description

Optional. Omitted from the Graph payload when blank - some tenants reject an empty-string description with a generic 400.

| Attribute | Value |
|---|---|
| Type | `String` |

### -GroupType

Assignment model. `Assigned` creates a static group. `Dynamic` requires `-MembershipRule`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Assigned |
| Valid values | Assigned, Dynamic |

### -MembershipRule

Dynamic membership rule. Only valid with `-GroupType Dynamic`. Use `user.*` properties for a dynamic user group, `device.*` properties for a dynamic device group.

| Attribute | Value |
|---|---|
| Type | `String` |

### -MembershipRuleProcessingState

Whether Entra evaluates the dynamic rule. Only valid with `-GroupType Dynamic`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | On |
| Valid values | On, Paused |

### -WhatIf / -Confirm

Standard risk-mitigation switches.

## Outputs

| Property | Type | Description |
|---|---|---|
| Id | String | New group GUID |
| Name | String | Display name |
| Description | String | Group description |
| GroupType | String | `Security` |
| MembershipType | String | `Assigned` or `Dynamic (On\|Paused)` |
| MembershipRule | String | The rule, when dynamic |

## Examples

Examples use the `U` (user-scoped) / `D` (device-scoped) naming convention that `Test-LKPolicyAssignment` uses as a scope heuristic.

### Example 1 - Assigned group (default)

```powershell
New-LKGroup -Name 'SG-Intune-U-Pilot Users' -Description 'Pilot users'
```

### Example 2 - Dynamic user group (all licensed, enabled Intune users)

```powershell
New-LKGroup -Name 'SG-Intune-U-All Users' -GroupType Dynamic `
    -MembershipRule '(user.accountEnabled -eq true) and (user.assignedPlans -any (assignedPlan.servicePlanId -eq "c1ec4a95-1f05-45b3-a911-aa3fa01094f5" -and assignedPlan.capabilityStatus -eq "Enabled"))'
```

The servicePlanId above matches the Intune service plan - adjust for your tenant's licensing.

### Example 3 - Dynamic device group (physical Windows devices)

```powershell
New-LKGroup -Name 'SG-Intune-D-Windows Physical' -GroupType Dynamic `
    -MembershipRule '(device.deviceModel -notContains "Virtual Machine") and (device.managementType -eq "MDM") and (device.deviceOSType -contains "Windows")'
```

### Example 4 - Dynamic device group (Autopilot-registered)

```powershell
New-LKGroup -Name 'SG-Intune-D-Windows Autopilot' -GroupType Dynamic `
    -MembershipRule '(device.devicePhysicalIDs -any _ -contains "[ZTDId]")'
```

### Example 5 - Per-manufacturer dynamic device groups

```powershell
'HP','Dell','Lenovo' | ForEach-Object {
    New-LKGroup -Name "SG-Intune-D-Windows $_" -GroupType Dynamic `
        -MembershipRule "(device.managementType -eq `"MDM`") and (device.deviceManufacturer -contains `"$_`")"
}
```

Useful for targeting BIOS/driver updates per vendor.

### Example 6 - Rule syntax with `-WhatIf` (dry run)

```powershell
New-LKGroup -Name 'SG-Test-U-Dynamic' -GroupType Dynamic `
    -MembershipRule '(user.department -eq "Engineering")' `
    -WhatIf
```

Shows the full Graph payload that would be sent without creating the group.

## Related

- [Add-LKGroupMember](Add-LKGroupMember.md) - add users/devices/groups as members
- [Remove-LKGroup](Remove-LKGroup.md)
- [Rename-LKGroup](Rename-LKGroup.md)
