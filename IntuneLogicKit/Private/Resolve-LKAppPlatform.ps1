function Resolve-LKAppPlatform {
    <#
    .SYNOPSIS
        Maps a MobileApp @odata.type to its target platform.
    .DESCRIPTION
        Returns one of 'Android', 'iOS', 'macOS', 'Windows', 'Web', or $null when
        the type can't be classified. Mirrors the @odata.type patterns handled by
        Resolve-LKAppDisplayType. Used by the -Platform filter on app-aware commands.

        Order matters: macOS is checked first because macOS bundles (Edge, Office,
        VPP, Defender) share keywords with their Windows counterparts. Windows is
        checked before the generic 'webApp' so that 'windowsWebApp' resolves to
        Windows rather than Web.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ODataType
    )

    switch -Wildcard ($ODataType) {
        # macOS - check first (macOS Edge/Office/VPP/Defender share keywords with Windows)
        '*macOS*'                       { return 'macOS' }

        # iOS
        '*iosVppApp'                    { return 'iOS' }
        '*iosStoreApp'                  { return 'iOS' }
        '*iosLobApp'                    { return 'iOS' }
        '*managedIOSStoreApp'           { return 'iOS' }
        '*managedIOSLobApp'             { return 'iOS' }

        # Android
        '*androidStoreApp'              { return 'Android' }
        '*androidLobApp'                { return 'Android' }
        '*androidManagedStoreApp'       { return 'Android' }
        '*managedAndroidStoreApp'       { return 'Android' }
        '*managedAndroidLobApp'         { return 'Android' }
        '*androidForWorkApp'            { return 'Android' }

        # Windows - including windowsWebApp (caught before the generic webApp below)
        '*win32LobApp'                  { return 'Windows' }
        '*win32CatalogApp'              { return 'Windows' }
        '*windowsMobileMSI'             { return 'Windows' }
        '*microsoftStoreForBusinessApp' { return 'Windows' }
        '*winGetApp'                    { return 'Windows' }
        '*officeSuiteApp'               { return 'Windows' }
        '*windowsMicrosoftEdgeApp'      { return 'Windows' }
        '*windowsWebApp'                { return 'Windows' }
        '*windowsAppX'                  { return 'Windows' }
        '*windowsUniversalAppX'         { return 'Windows' }
        '*windowsPhone*'                { return 'Windows' }

        # Web (generic web link/clip - windowsWebApp already handled above)
        '*webApp'                       { return 'Web' }

        default                         { return $null }
    }
}
