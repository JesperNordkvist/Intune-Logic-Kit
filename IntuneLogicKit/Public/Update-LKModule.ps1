function Update-LKModule {
    <#
    .SYNOPSIS
        Downloads and installs the latest release of Intune Logic Kit from GitHub.
    .DESCRIPTION
        Checks GitHub for the latest release, downloads the zip, extracts it over the
        current module directory, and reimports the module to load the new version.
        Session state is preserved across the update.
    .EXAMPLE
        Update-LKModule
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()

    $manifestPath = Join-Path $PSScriptRoot '..\IntuneLogicKit.psd1'
    $manifest = Import-PowerShellDataFile $manifestPath
    $currentVersion = [version]$manifest.ModuleVersion
    $moduleRoot = Split-Path $PSScriptRoot -Parent

    Write-Host "  Current version: v$currentVersion" -ForegroundColor Cyan

    try {
        $releaseUrl = "https://api.github.com/repos/$script:LKGitHubRepo/releases/latest"
        $releaseInfo = Invoke-RestMethod -Uri $releaseUrl -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-Warning "Could not reach GitHub: $($_.Exception.Message)"
        return
    }

    $latestTag = $releaseInfo.tag_name -replace '^v', ''
    $latestVersion = [version]$latestTag

    if ($latestVersion -le $currentVersion) {
        Write-Host "  Already up to date (v$currentVersion)." -ForegroundColor Green
        return
    }

    Write-Host "  Latest version:  v$latestVersion" -ForegroundColor Yellow

    if (-not $PSCmdlet.ShouldProcess("Intune Logic Kit v$currentVersion -> v$latestVersion", 'Update module')) {
        return
    }

    # Prefer an uploaded zip asset; fall back to the source archive
    $zipAsset = $releaseInfo.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    $downloadUrl = if ($zipAsset) { $zipAsset.browser_download_url } else { $releaseInfo.zipball_url }
    $zipName = if ($zipAsset) { $zipAsset.name } else { "IntuneLogicKit-v$latestTag.zip" }

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $zipName
    $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) "IntuneLogicKit_update_$latestTag"

    try {
        # Download
        Write-Progress -Activity 'Updating Intune Logic Kit' -Status "Downloading $zipName..." -PercentComplete 20
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

        # Extract
        Write-Progress -Activity 'Updating Intune Logic Kit' -Status 'Extracting...' -PercentComplete 45
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        # Locate the module in the extracted content
        Write-Progress -Activity 'Updating Intune Logic Kit' -Status 'Locating module files...' -PercentComplete 60
        $extractedManifest = Get-ChildItem -Path $tempExtract -Filter 'IntuneLogicKit.psd1' -Recurse | Select-Object -First 1
        if (-not $extractedManifest) {
            Write-Warning "Could not find IntuneLogicKit.psd1 in the downloaded archive."
            return
        }
        $extractedRoot = $extractedManifest.DirectoryName

        # Install
        Write-Progress -Activity 'Updating Intune Logic Kit' -Status 'Installing files...' -PercentComplete 75
        Copy-Item -Path "$extractedRoot\*" -Destination $moduleRoot -Recurse -Force

        # Reimport the module to load the new version
        Write-Progress -Activity 'Updating Intune Logic Kit' -Status 'Reimporting module...' -PercentComplete 90

        $savedSession = if ($script:LKSession) { $script:LKSession.Clone() } else { $null }
        $savedFilterCache = if ($script:LKFilterNameCache) { $script:LKFilterNameCache.Clone() } else { @{} }
        $savedPolicyNames = if ($script:LKPolicyNameCache) { [System.Collections.Generic.HashSet[string]]::new($script:LKPolicyNameCache) } else { $null }
        $savedGroupNames  = if ($script:LKGroupNameCache)  { [System.Collections.Generic.HashSet[string]]::new($script:LKGroupNameCache)  } else { $null }

        Import-Module "$moduleRoot\IntuneLogicKit.psd1" -Force -Global

        # Restore session state into the reloaded module
        if ($savedSession) {
            & (Get-Module IntuneLogicKit) {
                param($s, $fc, $pn, $gn)
                $script:LKSession = $s
                $script:LKFilterNameCache = $fc
                if ($pn) { $script:LKPolicyNameCache = $pn }
                if ($gn) { $script:LKGroupNameCache = $gn }
            } $savedSession $savedFilterCache $savedPolicyNames $savedGroupNames
        }

        Write-Progress -Activity 'Updating Intune Logic Kit' -Completed

        Write-Host ''
        Write-Host "  Updated to v$latestVersion and reimported successfully." -ForegroundColor Green
        Write-Host ''
    } catch {
        Write-Progress -Activity 'Updating Intune Logic Kit' -Completed
        Write-Warning "Update failed: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
