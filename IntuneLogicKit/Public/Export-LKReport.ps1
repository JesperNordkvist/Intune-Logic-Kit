function Export-LKReport {
    <#
    .SYNOPSIS
        Exports an Intune report to CSV - equivalent to clicking "Export" in the portal.
    .DESCRIPTION
        Runs a Microsoft Graph deviceManagement exportJobs request and downloads the
        resulting CSV. Supports the same reports as the Intune portal "Export" button,
        including device inventory, compliance, proactive remediation run states, app
        install status, configuration policy non-compliance, Defender agent status,
        and more.

        Platform script run states don't have an exportJobs report behind them, so
        they're fetched directly from /deviceManagement/deviceManagementScripts/{id}/deviceRunStates
        and written to CSV.

        Accepts pipeline input from Get-LKPolicy: pipe a Remediation, PlatformScript,
        or App policy and the report type and policy filter are auto-detected.
    .EXAMPLE
        Export-LKReport -ReportType Devices -Path .\devices.csv
        Exports the full managed devices report.
    .EXAMPLE
        Export-LKReport -PolicyName "Check BitLocker" -Path .\pr.csv
        Looks up "Check BitLocker", sees it's a proactive remediation, and exports the
        ProactiveRemediation report. -ReportType is inferred from the policy.
    .EXAMPLE
        Export-LKReport -PolicyName "Install Agent" -Path .\script.csv
        Same idea - "Install Agent" is a platform script, so the PlatformScript report
        is exported via the direct endpoint.
    .EXAMPLE
        Export-LKReport -PolicyId "abcd-1234-..." -Path .\out.csv
        Probes the remediation, platform script, and app endpoints to identify the policy
        and pick the right report.
    .EXAMPLE
        Export-LKReport -ReportType ProactiveRemediation -PolicyName "Check BitLocker" -Path .\pr.csv
        Explicit form - useful if a name collides across policy types.
    .EXAMPLE
        Get-LKPolicy -PolicyType Remediation -Name "Check BitLocker" | Export-LKReport -Path .\pr.csv
        Pipeline form - report type is auto-detected from the piped policy.
    .EXAMPLE
        Get-LKPolicy -PolicyType App -Name "Company Portal" | Export-LKReport -Path .\app.csv
        Exports app install status for a specific application.
    .EXAMPLE
        Export-LKReport -ReportType ActiveMalware -Path .\malware.csv
        Exports the active malware report.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByReportType')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(ParameterSetName = 'ByReportType')]
        [ValidateSet(
            'Devices', 'DeviceCompliance', 'DeviceNonCompliance', 'DevicesWithoutCompliancePolicy',
            'ConfigurationPolicyNonCompliance', 'ConfigurationPolicyNonComplianceSummary',
            'ProactiveRemediation', 'PlatformScript',
            'AppInstallStatus', 'AppInstallStatusByUser', 'DetectedApps',
            'DefenderAgents', 'ActiveMalware', 'Malware', 'FirewallStatus', 'Certificates'
        )]
        [string]$ReportType,

        [Parameter(ParameterSetName = 'ByReportType')]
        [string]$PolicyName,

        [Parameter(ParameterSetName = 'ByReportType')]
        [string]$PolicyId,

        [Parameter(ParameterSetName = 'ByReportType')]
        [string]$AppName,

        [Parameter(ParameterSetName = 'ByReportType')]
        [string]$AppId,

        [string]$Filter,

        [string[]]$Select,

        [Parameter(Mandatory)]
        [string]$Path,

        [int]$TimeoutSeconds = 300,

        [int]$PollIntervalSeconds = 3,

        [switch]$PassThru
    )

    begin {
        Assert-LKSession
        $pipelineItems = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($InputObject) {
            $pipelineItems.Add($InputObject)
        }
    }

    end {
        # Build the list of (reportType, policyId, label) tuples to export
        $jobs = [System.Collections.Generic.List[object]]::new()

        if ($pipelineItems.Count -gt 0) {
            foreach ($item in $pipelineItems) {
                $pType = $item.PolicyType
                $pId   = $item.Id
                $pName = $item.Name

                $mapped = switch ($pType) {
                    'Remediation'    { 'ProactiveRemediation' }
                    'PlatformScript' { 'PlatformScript' }
                    'App'            { 'AppInstallStatus' }
                    default          { $null }
                }

                if (-not $mapped) {
                    Write-Warning "Cannot export a report for policy type '$pType' ('$pName'). Supported pipeline types: Remediation, PlatformScript, App."
                    continue
                }

                $jobs.Add([PSCustomObject]@{
                    ReportType = $mapped
                    PolicyId   = $pId
                    Label      = $pName
                })
            }
        } else {
            # ByReportType (or inference). Two phases:
            #   1. If -ReportType is omitted, infer it from -PolicyName/-PolicyId/-AppName/-AppId
            #   2. Resolve any unresolved identifier the chosen report needs
            $resolvedId = $null
            $label      = $null

            if (-not $ReportType) {
                if ($PolicyName -or $PolicyId) {
                    $resolved = Resolve-LKReportablePolicy -PolicyName $PolicyName -PolicyId $PolicyId

                    if (-not $resolved -or @($resolved).Count -eq 0) {
                        $what = if ($PolicyName) { "named '$PolicyName'" } else { "with ID '$PolicyId'" }
                        throw "No proactive remediation, platform script, or app $what was found. Specify -ReportType explicitly if the policy is a different type."
                    }

                    if (@($resolved).Count -gt 1) {
                        $typesHit = (@($resolved) | ForEach-Object { $_.PolicyType } | Sort-Object -Unique) -join ', '
                        throw "Multiple policies match '$PolicyName' across types ($typesHit). Use -ReportType to disambiguate, or pass -PolicyId for an exact match."
                    }

                    $picked = @($resolved)[0]
                    $ReportType = switch ($picked.PolicyType) {
                        'Remediation'    { 'ProactiveRemediation' }
                        'PlatformScript' { 'PlatformScript' }
                        'App'            { 'AppInstallStatus' }
                        default          { throw "Policy '$($picked.Name)' has type '$($picked.PolicyType)' which has no exportable report." }
                    }
                    $resolvedId = $picked.Id
                    $label      = $picked.Name
                    Write-Verbose "Inferred -ReportType '$ReportType' from $($picked.PolicyType) policy '$($picked.Name)'."
                } elseif ($AppName -or $AppId) {
                    # No ReportType but app identifier given - default to per-device install status.
                    # The shared resolution branch below picks up AppName/AppId.
                    $ReportType = 'AppInstallStatus'
                } else {
                    throw 'You must specify -ReportType, -PolicyName, -PolicyId, -AppName, or -AppId (or pipe a policy from Get-LKPolicy).'
                }
            }

            if (-not $label) { $label = $ReportType }

            $reportEntry = $script:LKReportTypes | Where-Object { $_.Name -eq $ReportType }
            if (-not $reportEntry) {
                throw "Unknown report type '$ReportType'."
            }

            # Resolve identifier only if inference didn't already do it
            if (-not $resolvedId -and $reportEntry.RequiresPolicyId) {
                if ($PolicyId) {
                    $resolvedId = $PolicyId
                    $label = "$ReportType ($PolicyId)"
                } elseif ($PolicyName) {
                    $pipelineType = $reportEntry.AcceptsPipeline
                    if (-not $pipelineType) {
                        throw "Report '$ReportType' requires -PolicyId; cannot resolve by name for this report."
                    }
                    $resolved = Get-LKPolicy -PolicyType $pipelineType -Name $PolicyName -NameMatch Exact
                    if (-not $resolved) {
                        throw "No $pipelineType policy found matching '$PolicyName'."
                    }
                    if (@($resolved).Count -gt 1) {
                        throw "Multiple $pipelineType policies matched '$PolicyName'. Use -PolicyId to disambiguate."
                    }
                    $resolvedId = $resolved.Id
                    $label = $resolved.Name
                } else {
                    throw "Report '$ReportType' requires -PolicyName or -PolicyId."
                }
            } elseif (-not $resolvedId -and $reportEntry.RequiresAppId) {
                if ($AppId) {
                    $resolvedId = $AppId
                    $label = "$ReportType ($AppId)"
                } elseif ($AppName) {
                    $resolved = Get-LKPolicy -PolicyType App -Name $AppName -NameMatch Exact
                    if (-not $resolved) {
                        throw "No App found matching '$AppName'."
                    }
                    if (@($resolved).Count -gt 1) {
                        throw "Multiple Apps matched '$AppName'. Use -AppId to disambiguate."
                    }
                    $resolvedId = $resolved.Id
                    $label = $resolved.Name
                } else {
                    throw "Report '$ReportType' requires -AppName or -AppId."
                }
            }

            $jobs.Add([PSCustomObject]@{
                ReportType = $ReportType
                PolicyId   = $resolvedId
                Label      = $label
            })
        }

        if ($jobs.Count -eq 0) {
            Write-Warning 'No reports to export.'
            return
        }

        # If exporting multiple reports (pipeline with >1 item), use the -Path as a directory
        $multiMode = $jobs.Count -gt 1
        if ($multiMode) {
            $resolvedBase = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if (-not (Test-Path $resolvedBase)) {
                New-Item -ItemType Directory -Path $resolvedBase -Force | Out-Null
            } elseif (-not (Get-Item $resolvedBase).PSIsContainer) {
                throw "Multiple reports requested but -Path '$Path' is a file, not a directory."
            }
        }

        $exported = [System.Collections.Generic.List[object]]::new()

        foreach ($job in $jobs) {
            $reportEntry = $script:LKReportTypes | Where-Object { $_.Name -eq $job.ReportType }
            if (-not $reportEntry) {
                Write-Warning "Unknown report type '$($job.ReportType)' — skipping."
                continue
            }

            # Compute output path
            $outPath = if ($multiMode) {
                $safe = ($job.Label -replace '[\\/:*?"<>|]', '_')
                Join-Path $resolvedBase "$($job.ReportType)_$safe.csv"
            } else {
                $Path
            }

            $activity = "Exporting $($reportEntry.DisplayName)"

            try {
                switch ($reportEntry.Mode) {
                    'ExportJob' {
                        $effectiveFilter = $Filter
                        if (-not $effectiveFilter -and $reportEntry.RequiresPolicyId -and $job.PolicyId) {
                            $effectiveFilter = $reportEntry.PolicyIdFilterFmt -f $job.PolicyId
                        } elseif (-not $effectiveFilter -and $reportEntry.RequiresAppId -and $job.PolicyId) {
                            $effectiveFilter = $reportEntry.AppIdFilterFmt -f $job.PolicyId
                        }

                        $file = Invoke-LKExportJob -ReportName $reportEntry.ReportName `
                            -Filter $effectiveFilter `
                            -Select $Select `
                            -DestinationPath $outPath `
                            -TimeoutSeconds $TimeoutSeconds `
                            -PollIntervalSeconds $PollIntervalSeconds `
                            -Activity $activity
                    }
                    'DirectEndpoint' {
                        if (-not $job.PolicyId) {
                            throw "Direct-endpoint report '$($job.ReportType)' requires a policy ID."
                        }
                        $file = Export-LKReportFromDirectEndpoint -ReportEntry $reportEntry `
                            -PolicyId $job.PolicyId `
                            -DestinationPath $outPath `
                            -Activity $activity
                    }
                    default {
                        throw "Unknown report mode '$($reportEntry.Mode)'."
                    }
                }

                $exported.Add([PSCustomObject]@{
                    ReportType = $job.ReportType
                    Label      = $job.Label
                    Path       = $file.FullName
                    SizeKB     = [math]::Round($file.Length / 1KB, 1)
                })
            } catch {
                Write-Warning "Failed to export '$($job.Label)' ($($job.ReportType)): $($_.Exception.Message)"
            }
        }

        if ($exported.Count -eq 0) {
            Write-Warning 'No reports were exported.'
            return
        }

        Write-Host ''
        if ($exported.Count -eq 1) {
            $e = $exported[0]
            Write-Host "  Exported $($e.ReportType) to $($e.Path) ($($e.SizeKB) KB)" -ForegroundColor Green
        } else {
            Write-Host "  Exported $($exported.Count) reports:" -ForegroundColor Green
            foreach ($e in $exported) {
                Write-Host "    - $($e.Label) -> $($e.Path) ($($e.SizeKB) KB)" -ForegroundColor Gray
            }
        }
        Write-Host ''

        if ($PassThru) {
            $exported
        }
    }
}
