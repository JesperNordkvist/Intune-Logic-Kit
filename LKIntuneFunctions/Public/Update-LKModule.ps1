function Update-LKModule {
    <#
    .SYNOPSIS
        Downloads and installs the latest release of Intune Logic Kit from GitHub.
    .DESCRIPTION
        Checks GitHub for the latest release, downloads the zip, extracts it over the
        current module directory, and prompts the user to re-import the module.
    .EXAMPLE
        Update-LKModule
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()

    $manifestPath = Join-Path $PSScriptRoot '..\LKIntuneFunctions.psd1'
    $manifest = Import-PowerShellDataFile $manifestPath
    $currentVersion = [version]$manifest.ModuleVersion

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

    # Find the zip asset
    $zipAsset = $releaseInfo.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $zipAsset) {
        Write-Warning "No zip asset found in the latest release. Download manually:"
        Write-Warning "  $($releaseInfo.html_url)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Intune Logic Kit v$currentVersion -> v$latestVersion", 'Update module')) {
        return
    }

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $zipAsset.name
    $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) "LKIntuneFunctions_update_$latestTag"

    try {
        Write-Host "  Downloading $($zipAsset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

        # Clean up any previous extract
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }

        Write-Host "  Extracting..." -ForegroundColor Cyan
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        # The zip contains the module files directly (or in a subfolder)
        # Find where the .psd1 lives in the extracted content
        $extractedManifest = Get-ChildItem -Path $tempExtract -Filter 'LKIntuneFunctions.psd1' -Recurse | Select-Object -First 1
        if (-not $extractedManifest) {
            Write-Warning "Could not find LKIntuneFunctions.psd1 in the downloaded archive."
            return
        }
        $extractedRoot = $extractedManifest.DirectoryName

        Write-Host "  Installing to $moduleRoot..." -ForegroundColor Cyan
        Copy-Item -Path "$extractedRoot\*" -Destination $moduleRoot -Recurse -Force

        Write-Host ''
        Write-Host "  Updated to v$latestVersion." -ForegroundColor Green
        Write-Host "  Run the following to reload:" -ForegroundColor Yellow
        Write-Host "    Remove-Module LKIntuneFunctions; Import-Module '$moduleRoot\LKIntuneFunctions.psd1'" -ForegroundColor White
        Write-Host ''
    } catch {
        Write-Warning "Update failed: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
