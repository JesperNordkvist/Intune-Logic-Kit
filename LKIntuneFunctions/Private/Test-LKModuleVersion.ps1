function Test-LKModuleVersion {
    <#
    .SYNOPSIS
        Checks GitHub for a newer module release and notifies the user.
    #>
    try {
        $manifestPath = Join-Path $PSScriptRoot '..\LKIntuneFunctions.psd1'
        $manifest = Import-PowerShellDataFile $manifestPath
        $currentVersion = [version]$manifest.ModuleVersion

        $releaseUrl = "https://api.github.com/repos/$script:LKGitHubRepo/releases/latest"
        $releaseInfo = Invoke-RestMethod -Uri $releaseUrl -TimeoutSec 5 -ErrorAction Stop
        $latestTag = $releaseInfo.tag_name -replace '^v', ''
        $latestVersion = [version]$latestTag

        if ($latestVersion -gt $currentVersion) {
            Write-Host ''
            Write-Host "  Update available: v$latestVersion (installed: v$currentVersion)" -ForegroundColor Yellow
            Write-Host "  Download: $($releaseInfo.html_url)" -ForegroundColor Yellow
            Write-Host ''
        }
    } catch {
        # Version check is non-critical - fail silently
    }
}
