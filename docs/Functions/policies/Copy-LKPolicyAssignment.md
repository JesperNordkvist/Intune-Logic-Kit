---
title: Copy-LKPolicyAssignment
nav_order: 6
---

# Copy-LKPolicyAssignment

Copies all assignments from a source policy to one or more target policies.

## Syntax

```text
# Pipeline (source object + pipeline targets)
Copy-LKPolicyAssignment
    -SourcePolicy <PSCustomObject>
    [-InputObject <PSCustomObject>]
    [-Mode <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By target ID
Copy-LKPolicyAssignment
    -SourcePolicy <PSCustomObject>
    -TargetPolicyId <String>
    [-TargetPolicyType <String>]
    [-Mode <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]

# By source ID
Copy-LKPolicyAssignment
    -SourcePolicyId <String>
    [-SourcePolicyType <String>]
    -TargetPolicyId <String>
    [-TargetPolicyType <String>]
    [-Mode <String>]
    [-WhatIf] [-Confirm]
    [<CommonParameters>]
```

## Description

Reads all assignments from the source policy and writes them to each target. In `Replace` mode (default), existing target assignments are overwritten. In `Merge` mode, source assignments are added without removing existing ones (duplicates are skipped).

## Parameters

### -SourcePolicy

A policy object from `Get-LKPolicy` to copy assignments from.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Required | Yes (ByPipeline, ByTargetId) |

### -SourcePolicyId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (BySourceId) |

### -SourcePolicyType

Optional - auto-resolved if omitted.

| Attribute | Value |
|---|---|
| Type | `String` |

### -InputObject

Target policy from the pipeline.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -TargetPolicyId

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes (ByTargetId, BySourceId) |

### -TargetPolicyType

Optional - auto-resolved if omitted.

| Attribute | Value |
|---|---|
| Type | `String` |

### -Mode

`Replace` (default) overwrites all target assignments. `Merge` adds without removing existing.

| Attribute | Value |
|---|---|
| Type | `String` |
| Default | Replace |
| Valid values | Replace, Merge |

## Outputs

| Property | Type | Description |
|---|---|---|
| SourcePolicy | String | Source policy name |
| TargetPolicy | String | Target policy name |
| AssignmentsCopied | Int | Number of assignments copied |
| Mode | String | Replace or Merge |
| Action | String | `AssignmentsCopied` |

## Examples

### Example 1 - Copy to all matching targets

```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Get-LKPolicy -Name "Contoso*" -NameMatch Wildcard | Copy-LKPolicyAssignment -SourcePolicy $source
```

### Example 2 - Merge mode

```powershell
$source = Get-LKPolicy -Name "Reference Policy" -NameMatch Exact
Get-LKPolicy -Name "Contoso*" | Copy-LKPolicyAssignment -SourcePolicy $source -Mode Merge
```

## Related

- [Get-LKPolicyAssignment](Get-LKPolicyAssignment.md)
- [Add-LKPolicyAssignment](Add-LKPolicyAssignment.md)
