---
title: New-LKSession
nav_order: 19
---

# New-LKSession

Opens an interactive login and connects to Microsoft Graph for Intune administration.

## Syntax

```text
New-LKSession [<CommonParameters>]
```

## Description

Launches a browser-based sign-in prompt using delegated authentication with the built-in Microsoft Graph PowerShell app - no custom app registration required. The user's Intune Administrator role provides effective permissions.

If a previous session was established against a different tenant or account, a warning is shown so you don't accidentally work in the wrong environment.

## Parameters

This command has no parameters.

## Outputs

| Property | Type | Description |
|---|---|---|
| TenantName | String | Display name of the connected tenant |
| TenantId | String | Tenant GUID |
| Account | String | Signed-in user's UPN |
| ConnectedAt | DateTime | When the session was established |

## Examples

### Example 1 - Connect to your tenant
```powershell
New-LKSession
```
