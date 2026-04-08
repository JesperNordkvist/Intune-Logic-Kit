function Compare-LKDevice {
    <#
    .SYNOPSIS
        Compares two or more Intune managed devices side by side.
    .DESCRIPTION
        Fetches device details and optionally discovered apps for each device, then
        shows the differences. Useful for detecting drift between devices, such as
        comparing an AVD production device against its golden image.
    .EXAMPLE
        Get-LKDevice -Name "AVD-PROD-01", "AVD-GOLD-01" -NameMatch Exact | Compare-LKDevice
        Compares two devices piped from Get-LKDevice.
    .EXAMPLE
        Compare-LKDevice -DeviceName "AVD-PROD-01", "AVD-GOLD-01"
        Compares two devices by name.
    .EXAMPLE
        Compare-LKDevice -DeviceName "AVD-PROD-01", "AVD-GOLD-01" -IncludeApps
        Includes a comparison of discovered apps and their versions.
    .EXAMPLE
        Compare-LKDevice -DeviceName "AVD-PROD-01", "AVD-GOLD-01" -IncludeApps -IncludeEqual
        Also shows apps and properties that are identical across devices.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'ByPipeline')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string[]]$DeviceName,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string[]]$DeviceId,

        [switch]$IncludeApps,

        [switch]$IncludeEqual
    )

    begin {
        Assert-LKSession
        $devices = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($InputObject) {
            $devices.Add($InputObject)
        }
    }

    end {
        # Resolve devices by name or ID
        if ($DeviceName) {
            foreach ($name in $DeviceName) {
                $escaped = $name.Replace("'", "''")
                try {
                    $found = Invoke-LKGraphRequest -Method GET `
                        -Uri "/deviceManagement/managedDevices?`$filter=deviceName eq '$escaped'&`$select=id,deviceName" `
                        -ApiVersion 'v1.0' -All
                    if ($found -and $found.Count -gt 0) {
                        $devices.Add([PSCustomObject]@{ Id = $found[0].id; DeviceName = $found[0].deviceName })
                    } else {
                        Write-Warning "Device '$name' not found."
                    }
                } catch {
                    Write-Warning "Failed to find device '$name': $($_.Exception.Message)"
                }
            }
        } elseif ($DeviceId) {
            foreach ($id in $DeviceId) {
                $devices.Add([PSCustomObject]@{ Id = $id; DeviceName = $null })
            }
        }

        if ($devices.Count -lt 2) {
            Write-Warning "At least 2 devices are required for comparison. Got $($devices.Count)."
            return
        }

        # Fetch full details for each device
        $deviceData = [ordered]@{}
        $deviceApps  = [ordered]@{}
        $count = 0

        foreach ($dev in $devices) {
            $count++
            $label = if ($dev.DeviceName) { $dev.DeviceName } else { $dev.Id }
            Write-Progress -Activity 'Comparing devices' -Status "Fetching $label ($count of $($devices.Count))" -PercentComplete (($count / $devices.Count) * 100)

            try {
                $full = Invoke-LKGraphRequest -Method GET -Uri "/deviceManagement/managedDevices/$($dev.Id)" -ApiVersion 'v1.0'
            } catch {
                Write-Warning "Failed to fetch device '$label': $($_.Exception.Message)"
                continue
            }

            $dName = $full.deviceName
            $deviceData[$dName] = [ordered]@{
                'OS'               = $full.operatingSystem
                'OS Version'       = $full.osVersion
                'Compliance'       = $full.complianceState
                'Management State' = $full.managementState
                'Enrollment Type'  = $full.deviceEnrollmentType
                'Join Type'        = $full.joinType
                'Ownership'        = $full.managedDeviceOwnerType
                'Manufacturer'     = $full.manufacturer
                'Model'            = $full.model
                'Serial Number'    = $full.serialNumber
                'Encrypted'        = $full.isEncrypted
                'Total Storage GB' = [math]::Round($full.totalStorageSpaceInBytes / 1GB, 2)
                'Free Storage GB'  = [math]::Round($full.freeStorageSpaceInBytes / 1GB, 2)
                'Enrolled'         = $full.enrolledDateTime
                'Last Sync'        = $full.lastSyncDateTime
                'User'             = $full.userDisplayName
            }

            if ($IncludeApps) {
                Write-Progress -Activity 'Comparing devices' -Status "Fetching apps for $dName" -PercentComplete (($count / $devices.Count) * 100)
                try {
                    $apps = Invoke-LKGraphRequest -Method GET `
                        -Uri "/deviceManagement/managedDevices/$($dev.Id)/detectedApps?`$select=displayName,version" `
                        -ApiVersion 'beta' -All
                    $appMap = @{}
                    foreach ($app in $apps) {
                        if ($app.displayName) { $appMap[$app.displayName] = $app.version }
                    }
                    $deviceApps[$dName] = $appMap
                } catch {
                    Write-Warning "Failed to fetch apps for '$dName': $($_.Exception.Message)"
                    $deviceApps[$dName] = @{}
                }
            }
        }

        Write-Progress -Activity 'Comparing devices' -Completed

        if ($deviceData.Count -lt 2) {
            Write-Warning "Could not fetch details for at least 2 devices."
            return
        }

        $deviceNames = @($deviceData.Keys)
        $separator = [string]([char]0x2500) * 70

        # --- Device properties comparison ---
        Write-Host ''
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host '  DEVICE PROPERTIES' -ForegroundColor Cyan
        Write-Host $separator -ForegroundColor DarkGray

        $allProps = $deviceData[$deviceNames[0]].Keys
        $propResults = [System.Collections.Generic.List[object]]::new()

        foreach ($prop in $allProps) {
            $values = @{}
            foreach ($dName in $deviceNames) {
                $val = $deviceData[$dName][$prop]
                $values[$dName] = if ($null -eq $val) { '(unknown)' } else { "$val" }
            }

            $distinct = @($values.Values | Select-Object -Unique)
            $isEqual = $distinct.Count -le 1

            if (-not $IncludeEqual -and $isEqual) { continue }

            $propResults.Add(@{ Property = $prop; Values = $values; IsEqual = $isEqual })
        }

        if ($propResults.Count -eq 0) {
            Write-Host ''
            Write-Host '  All device properties are identical.' -ForegroundColor Green
        } else {
            $propData = $propResults | ForEach-Object {
                $row = [PSCustomObject]@{
                    Property = $_.Property
                    Status   = if ($_.IsEqual) { 'Equal' } else { 'Different' }
                }
                foreach ($dName in $deviceNames) {
                    $val = $_.Values[$dName]
                    $truncName = if ($dName.Length -gt 25) { $dName.Substring(0, 22) + '...' } else { $dName }
                    if ($val.Length -gt 30) { $val = $val.Substring(0, 27) + '...' }
                    $row | Add-Member -NotePropertyName $truncName -NotePropertyValue $val
                }
                $row
            }

            $propColumns = @('Property', 'Status') + @($deviceNames | ForEach-Object {
                if ($_.Length -gt 25) { $_.Substring(0, 22) + '...' } else { $_ }
            })

            Write-LKTable -Data $propData -Columns $propColumns -ColorRules @{
                'Status' = @{
                    'Equal'     = 'Green'
                    'Different' = 'Yellow'
                }
            }
        }

        # --- App comparison ---
        if ($IncludeApps -and $deviceApps.Count -ge 2) {
            Write-Host $separator -ForegroundColor DarkGray
            Write-Host '  DETECTED APPS' -ForegroundColor Cyan
            Write-Host $separator -ForegroundColor DarkGray

            $allAppNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($dName in $deviceNames) {
                if ($deviceApps[$dName]) {
                    foreach ($appName in $deviceApps[$dName].Keys) {
                        $allAppNames.Add($appName) | Out-Null
                    }
                }
            }

            $appResults = [System.Collections.Generic.List[object]]::new()

            foreach ($appName in ($allAppNames | Sort-Object)) {
                $versions = @{}
                $presentCount = 0
                foreach ($dName in $deviceNames) {
                    $ver = if ($deviceApps[$dName] -and $deviceApps[$dName].ContainsKey($appName)) {
                        $presentCount++
                        $deviceApps[$dName][$appName]
                    } else { $null }
                    $versions[$dName] = $ver
                }

                $presentVersions = @($versions.Values | Where-Object { $null -ne $_ } | Select-Object -Unique)
                $allPresent = $presentCount -eq $deviceNames.Count
                $isEqual = $allPresent -and $presentVersions.Count -le 1

                if (-not $IncludeEqual -and $isEqual) { continue }

                $status = if ($isEqual) { 'Equal' }
                          elseif (-not $allPresent) { 'Missing' }
                          else { 'Different' }

                $appResults.Add(@{ AppName = $appName; Versions = $versions; Status = $status })
            }

            if ($appResults.Count -eq 0) {
                Write-Host ''
                if ($IncludeEqual) {
                    Write-Host '  No detected apps found.' -ForegroundColor DarkGray
                } else {
                    Write-Host '  All detected apps are identical across devices.' -ForegroundColor Green
                }
            } else {
                $appData = $appResults | ForEach-Object {
                    $row = [PSCustomObject]@{
                        App    = if ($_.AppName.Length -gt 40) { $_.AppName.Substring(0, 37) + '...' } else { $_.AppName }
                        Status = $_.Status
                    }
                    foreach ($dName in $deviceNames) {
                        $ver = $_.Versions[$dName]
                        $display = if ($null -eq $ver) { '(not installed)' } else { "$ver" }
                        $truncName = if ($dName.Length -gt 25) { $dName.Substring(0, 22) + '...' } else { $dName }
                        if ($display.Length -gt 25) { $display = $display.Substring(0, 22) + '...' }
                        $row | Add-Member -NotePropertyName $truncName -NotePropertyValue $display
                    }
                    $row
                }

                $appColumns = @('App', 'Status') + @($deviceNames | ForEach-Object {
                    if ($_.Length -gt 25) { $_.Substring(0, 22) + '...' } else { $_ }
                })

                Write-LKTable -Data $appData -Columns $appColumns -ColorRules @{
                    'Status' = @{
                        'Equal'     = 'Green'
                        'Different' = 'Yellow'
                        'Missing'   = 'DarkGray'
                    }
                }

                $diffCount = @($appResults | Where-Object { $_.Status -eq 'Different' }).Count
                $missCount = @($appResults | Where-Object { $_.Status -eq 'Missing' }).Count
                Write-Host "  $($appResults.Count) app(s) shown ($diffCount different, $missCount missing)." -ForegroundColor Gray
            }
        }

        Write-Host ''
        Write-Host $separator -ForegroundColor DarkGray
        Write-Host ''
    }
}
