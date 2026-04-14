function Invoke-LKExportJob {
    <#
    .SYNOPSIS
        Submits, polls, and downloads the result of a Microsoft Graph
        /deviceManagement/reports/exportJobs request.
    .DESCRIPTION
        Internal helper that runs the full async export flow used by the Intune portal's
        "Export" button:
          1. POST /deviceManagement/reports/exportJobs to create a job
          2. Poll the job until status = completed (or failed/timeout)
          3. Download the resulting ZIP from the signed URL
          4. Extract the CSV inside and copy it to the requested destination path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReportName,

        [string]$Filter,

        [string[]]$Select,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [int]$TimeoutSeconds = 300,

        [int]$PollIntervalSeconds = 3,

        [string]$Activity = 'Exporting Intune report'
    )

    $body = [ordered]@{
        reportName       = $ReportName
        format           = 'csv'
        localizationType = 'LocalizedValuesAsAdditionalColumn'
    }
    if ($Filter) { $body['filter'] = $Filter }
    if ($Select) { $body['select'] = @($Select) }

    Write-Progress -Activity $Activity -Status "Submitting export job for '$ReportName'..." -PercentComplete 5

    try {
        $job = Invoke-LKGraphRequest -Method POST `
            -Uri '/deviceManagement/reports/exportJobs' `
            -ApiVersion 'beta' `
            -Body $body
    } catch {
        Write-Progress -Activity $Activity -Completed
        throw "Failed to submit exportJobs request for '$ReportName': $($_.Exception.Message)"
    }

    if (-not $job.id) {
        Write-Progress -Activity $Activity -Completed
        throw "Export job submission returned no job ID."
    }

    $jobId      = $job.id
    $deadline   = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastStatus = $job.status

    while ($true) {
        $remaining = ($deadline - (Get-Date)).TotalSeconds
        if ($remaining -le 0) {
            Write-Progress -Activity $Activity -Completed
            throw "Export job '$ReportName' did not complete within $TimeoutSeconds seconds (last status: $lastStatus)."
        }

        # Map elapsed/timeout to a 10–90% progress band
        $elapsed = $TimeoutSeconds - $remaining
        $pct = [Math]::Min(90, [Math]::Max(10, 10 + (($elapsed / $TimeoutSeconds) * 80)))
        Write-Progress -Activity $Activity -Status "Waiting for '$ReportName' (status: $lastStatus)..." -PercentComplete $pct

        Start-Sleep -Seconds $PollIntervalSeconds

        try {
            $job = Invoke-LKGraphRequest -Method GET `
                -Uri "/deviceManagement/reports/exportJobs('$jobId')" `
                -ApiVersion 'beta'
        } catch {
            Write-Progress -Activity $Activity -Completed
            throw "Failed to poll export job '$jobId': $($_.Exception.Message)"
        }

        $lastStatus = $job.status
        if ($lastStatus -eq 'completed') { break }
        if ($lastStatus -eq 'failed')    {
            Write-Progress -Activity $Activity -Completed
            throw "Export job '$ReportName' failed on the server."
        }
    }

    if (-not $job.url) {
        Write-Progress -Activity $Activity -Completed
        throw "Completed export job '$ReportName' returned no download URL."
    }

    Write-Progress -Activity $Activity -Status 'Downloading report archive...' -PercentComplete 92

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("LKExport_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempZip = Join-Path $tempDir 'report.zip'

    # Suppress Invoke-WebRequest's own progress bar (slows PS 5.1 dramatically)
    $oldPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $job.url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
    } catch {
        $ProgressPreference = $oldPref
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Progress -Activity $Activity -Completed
        throw "Failed to download exported report archive: $($_.Exception.Message)"
    }
    $ProgressPreference = $oldPref

    Write-Progress -Activity $Activity -Status 'Extracting CSV...' -PercentComplete 96

    try {
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force -ErrorAction Stop
    } catch {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Progress -Activity $Activity -Completed
        throw "Failed to extract exported report archive: $($_.Exception.Message)"
    }

    $csvFile = Get-ChildItem -Path $tempDir -Filter '*.csv' -File -Recurse | Select-Object -First 1
    if (-not $csvFile) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Progress -Activity $Activity -Completed
        throw "No CSV file found in the exported report archive."
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    $destDir = Split-Path -Parent $resolvedPath
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -Path $csvFile.FullName -Destination $resolvedPath -Force

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Progress -Activity $Activity -Completed

    Get-Item -Path $resolvedPath
}
