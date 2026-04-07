---
title: Update-LKModule
nav_order: 28
---

# Update-LKModule

Downloads and installs the latest release of LKIntuneFunctions from GitHub.

## Syntax

```text
Update-LKModule
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

## Description

Checks GitHub for the latest release, compares it to the installed version, and if an update is available downloads the zip asset, extracts it, and overwrites the current module directory. After updating, the user is prompted to re-import the module.

The confirmation prompt is enabled by default (`ConfirmImpact = 'High'`). Use `-WhatIf` to preview the update without making changes.

## Parameters

### -WhatIf

Shows what the update would do without making any changes.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

### -Confirm

Prompts for confirmation before updating. Enabled by default.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Examples

### Example 1 - Update the module

```powershell
Update-LKModule
```

### Example 2 - Preview without updating

```powershell
Update-LKModule -WhatIf
```

### Example 3 - Skip confirmation

```powershell
Update-LKModule -Confirm:$false
```

## Related

- [New-LKSession](New-LKSession.md) - automatic version check on connect
