---
title: New-LKSession
nav_order: 19
---

# New-LKSession

Opens an interactive login and connects to Microsoft Graph for Intune administration.

## Syntax

```text
New-LKSession [-ReadOnly] [<CommonParameters>]
```

## Description

Launches a browser-based sign-in prompt using delegated authentication with the built-in Microsoft Graph PowerShell app - no custom app registration required. The user's Intune Administrator role provides effective permissions.

If a previous session was established against a different tenant or account, a warning is shown so you don't accidentally work in the wrong environment.

## Parameters

### -ReadOnly

Connect with read-only Graph scopes only. The sign-in consents to no `*.ReadWrite.All` permissions, so the module can be used for auditing in tenants that won't grant write access. Any mutating LK command (`Add-`/`Remove-`/`Rename-`/`New-`/`Copy-LKPolicyAssignment`, group edits, device actions, …) refuses with a clear message while the session is read-only.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |
| Required | No |

## Outputs

| Property | Type | Description |
|---|---|---|
| TenantName | String | Display name of the connected tenant |
| TenantId | String | Tenant GUID |
| Account | String | Signed-in user's UPN |
| ReadOnly | Boolean | True when connected with `-ReadOnly` |
| ConnectedAt | DateTime | When the session was established |

## Notes

After connecting, the module automatically checks GitHub for a newer release. If one is available, a message is displayed with the latest version number. Run `Update-LKModule` to update in place.

## Examples

### Example 1 - Connect to your tenant

```powershell
New-LKSession
```

### Example 2 - Connect for auditing only (read-only)

```powershell
New-LKSession -ReadOnly
```

No write scopes are requested, and write commands are disabled for the session.

## Related

- [Close-LKSession](Close-LKSession.md)
- [Get-LKSession](Get-LKSession.md)
- [Update-LKModule](Update-LKModule.md)
