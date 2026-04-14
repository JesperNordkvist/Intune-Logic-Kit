---
title: Export-LKReport
nav_order: 8
---

# Export-LKReport

Exports an Intune report to CSV — the same reports you get from the Intune portal's "Export" button.

## Syntax

```text
# By report type / policy identifier
Export-LKReport
    [-ReportType <String>]
    [-PolicyName <String>]
    [-PolicyId <String>]
    [-AppName <String>]
    [-AppId <String>]
    [-Filter <String>]
    [-Select <String[]>]
    -Path <String>
    [-TimeoutSeconds <Int32>]
    [-PollIntervalSeconds <Int32>]
    [-PassThru]
    [<CommonParameters>]

# Pipeline
Export-LKReport
    [-InputObject <PSCustomObject>]
    [-Filter <String>]
    [-Select <String[]>]
    -Path <String>
    [-TimeoutSeconds <Int32>]
    [-PollIntervalSeconds <Int32>]
    [-PassThru]
    [<CommonParameters>]
```

You must supply at least one of `-ReportType`, `-PolicyName`, `-PolicyId`, `-AppName`, or `-AppId` — or pipe a policy from `Get-LKPolicy`.

## Description

Submits a Microsoft Graph `/deviceManagement/reports/exportJobs` request, polls until completion, downloads the resulting ZIP, and extracts the CSV to the destination path. This is the same mechanism the Intune portal uses behind the **Export** button in report views.

Platform script device run states don't have an `exportJobs` report — those are fetched directly from `/deviceManagement/deviceManagementScripts/{id}/deviceRunStates` and flattened to CSV.

`-ReportType` is **optional**. If you supply `-PolicyName` or `-PolicyId` instead, the cmdlet looks the policy up across the reportable types (Remediation, PlatformScript, App) and picks the right report on its own:

| Resolved policy type | Inferred report |
|---|---|
| `Remediation` | `ProactiveRemediation` |
| `PlatformScript` | `PlatformScript` |
| `App` | `AppInstallStatus` |

The same inference happens when you pipe a policy from `Get-LKPolicy`. Use `-ReportType` explicitly only when (a) you want a tenant-wide report like `Devices` / `DeviceCompliance` / `ActiveMalware` that doesn't tie to a single policy, (b) you want a non-default per-app report like `AppInstallStatusByUser`, or (c) a name collides across policy types and you need to disambiguate.

If multiple policies are piped, `-Path` is treated as a directory and one CSV is written per policy (named `ReportType_PolicyName.csv`).

## Parameters

### -ReportType

The report to export. Optional — if omitted, it's inferred from `-PolicyName`, `-PolicyId`, `-AppName`, or `-AppId`. Required only for tenant-wide reports that don't tie to a single policy (`Devices`, `DeviceCompliance`, `ActiveMalware`, etc.).

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |
| Valid values | Devices, DeviceCompliance, DeviceNonCompliance, DevicesWithoutCompliancePolicy, ConfigurationPolicyNonCompliance, ConfigurationPolicyNonComplianceSummary, ProactiveRemediation, PlatformScript, AppInstallStatus, AppInstallStatusByUser, DetectedApps, DefenderAgents, ActiveMalware, Malware, FirewallStatus, Certificates |

### -PolicyName

For per-policy reports (`ProactiveRemediation`, `PlatformScript`). Resolved via `Get-LKPolicy` with exact name match.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -PolicyId

For per-policy reports when you already have the ID or when multiple policies share a name.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -AppName

For `AppInstallStatus` / `AppInstallStatusByUser`. Resolved via `Get-LKPolicy -PolicyType App`.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -AppId

Direct application ID for per-app reports.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -InputObject

An `LKPolicy` object from `Get-LKPolicy`. Accepted from the pipeline. Supported policy types: `Remediation`, `PlatformScript`, `App`.

| Attribute | Value |
|---|---|
| Type | `PSCustomObject` |
| Pipeline | ByValue |

### -Filter

Raw OData filter passed to the export job. Overrides the automatic `PolicyId` / `ApplicationId` filter. Use this for advanced scenarios.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | No |

### -Select

Column projection passed to the export job. When omitted, the full column set is returned.

| Attribute | Value |
|---|---|
| Type | `String[]` |
| Required | No |

### -Path

Output CSV file path. When multiple reports are piped in, this is treated as a directory.

| Attribute | Value |
|---|---|
| Type | `String` |
| Required | Yes |

### -TimeoutSeconds

Maximum time to wait for the export job to complete. Default: `300`.

| Attribute | Value |
|---|---|
| Type | `Int32` |
| Default | 300 |

### -PollIntervalSeconds

How often to poll the export job for completion. Default: `3`.

| Attribute | Value |
|---|---|
| Type | `Int32` |
| Default | 3 |

### -PassThru

Emits an object describing each exported report (`ReportType`, `Label`, `Path`, `SizeKB`) to the pipeline.

| Attribute | Value |
|---|---|
| Type | `SwitchParameter` |

## Examples

### Example 1 — Just give it a policy name

```powershell
Export-LKReport -PolicyName "Check BitLocker" -Path .\pr.csv
```

The cmdlet looks up "Check BitLocker", sees it's a proactive remediation, and exports the `ProactiveRemediation` report. No `-ReportType` needed.

### Example 2 — Same idea for a platform script

```powershell
Export-LKReport -PolicyName "Install Agent" -Path .\script.csv
```

Resolves to a platform script and uses the direct `/deviceRunStates` endpoint.

### Example 3 — By policy ID

```powershell
Export-LKReport -PolicyId "abcd1234-..." -Path .\out.csv
```

Probes the remediation, platform script, and app endpoints to find the policy and pick the right report.

### Example 4 — Tenant-wide reports (no policy)

```powershell
Export-LKReport -ReportType Devices -Path .\devices.csv
Export-LKReport -ReportType DeviceCompliance -Path .\compliance.csv
Export-LKReport -ReportType ActiveMalware -Path .\malware.csv
```

These reports don't tie to a single policy, so `-ReportType` is required.

### Example 5 — Disambiguate when names collide

```powershell
Export-LKReport -ReportType ProactiveRemediation -PolicyName "Check BitLocker" -Path .\pr.csv
```

Useful only if the same name exists across multiple policy types (e.g. a platform script *and* a remediation called "Check BitLocker").

### Example 6 — Pipeline from Get-LKPolicy

```powershell
Get-LKPolicy -PolicyType Remediation -Name "Check BitLocker" | Export-LKReport -Path .\pr.csv
```

Equivalent to Example 1 but lets you preview the policy first.

### Example 7 — Export every remediation into a folder

```powershell
Get-LKPolicy -PolicyType Remediation | Export-LKReport -Path .\remediations\
```

When multiple policies are piped, `-Path` becomes a directory and one CSV is written per policy.

### Example 8 — Per-user app install status

```powershell
Export-LKReport -ReportType AppInstallStatusByUser -AppName "Company Portal" -Path .\cp-by-user.csv
```

`AppInstallStatus` is the default for app inference; use `-ReportType` explicitly when you want the per-user variant instead.

### Example 9 — Raw OData filter override

```powershell
Export-LKReport -ReportType Devices -Filter "(OwnerType eq 'company')" -Path .\corp-devices.csv
```

### Example 10 — Get the file info back for further processing

```powershell
$report = Export-LKReport -ReportType DeviceCompliance -Path .\compliance.csv -PassThru
Import-Csv $report.Path | Where-Object ComplianceState -ne 'Compliant'
```

## Outputs

Writes the CSV to `-Path`. With `-PassThru`, emits one object per exported report:

| Property | Type | Description |
|---|---|---|
| ReportType | String | The report type name |
| Label | String | The policy/app name or report type label |
| Path | String | Full path to the written CSV |
| SizeKB | Double | File size in KB |

## Notes

- Reports backed by `exportJobs` run asynchronously on the Graph service. The cmdlet polls every `-PollIntervalSeconds` seconds until completion or `-TimeoutSeconds` is exceeded. Large tenants may need a higher timeout (e.g. `-TimeoutSeconds 900` for a 15-minute ceiling).
- The CSV comes back localized (display names for enum values) because the underlying job uses `localizationType = LocalizedValuesAsAdditionalColumn`.
- Platform script run states are fetched with `$expand=managedDevice`, so the output includes device name and primary user alongside run state.
- `-Filter` expects an OData filter string in the exact format Graph expects, e.g. `(PolicyId eq 'guid-here')`. When omitted, the cmdlet builds the filter automatically from `-PolicyId` / `-AppId`.

## Related

- [Export-LKPolicy](Export-LKPolicy.md) — export policies and settings
- [Get-LKPolicy](Get-LKPolicy.md) — feeds the pipeline path
- [Get-LKDevice](../devices/Get-LKDevice.md) — query devices directly without an export job
