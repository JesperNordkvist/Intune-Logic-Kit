---
title: Get-LKSession
nav_order: 15
---

# Get-LKSession

Returns the current LKIntuneFunctions session info.

## Syntax

```text
Get-LKSession [<CommonParameters>]
```

## Description

Shows the tenant, account, and connection details for the active session. Attempts to restore a previous session if the Graph token cache is still valid.

## Parameters

This command has no parameters.

## Outputs

| Property | Type | Description |
|---|---|---|
| TenantName | String | Display name of the connected tenant |
| TenantId | String | Tenant GUID |
| Account | String | Signed-in user's UPN |
| Scopes | String[] | Active Graph permission scopes |
| ConnectedAt | DateTime | When the session was established |

## Examples

### Example 1 - Check current session
```powershell
Get-LKSession
```
