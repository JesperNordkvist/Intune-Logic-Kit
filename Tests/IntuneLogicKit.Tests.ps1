BeforeAll {
    $ModulePath = "$PSScriptRoot\..\IntuneLogicKit\IntuneLogicKit.psd1"
    Import-Module $ModulePath -Force
}

Describe 'Module: IntuneLogicKit' {
    It 'Should import without errors' {
        Get-Module -Name IntuneLogicKit | Should -Not -BeNullOrEmpty
    }

    It 'Should export all expected public functions' {
        $expectedFunctions = @(
            'New-LKSession'
            'Get-LKSession'
            'Close-LKSession'
            'Get-LKPolicy'
            'Get-LKPolicyAssignment'
            'Add-LKPolicyAssignment'
            'Remove-LKPolicyAssignment'
            'Add-LKPolicyExclusion'
            'Remove-LKPolicyExclusion'
            'Copy-LKPolicyAssignment'
            'Rename-LKPolicy'
            'Get-LKGroup'
            'New-LKGroup'
            'Remove-LKGroup'
            'Rename-LKGroup'
            'Get-LKGroupAssignment'
            'Get-LKGroupMember'
            'Add-LKGroupMember'
            'Remove-LKGroupMember'
            'Get-LKUser'
            'Get-LKDevice'
            'Get-LKDeviceDetail'
            'Invoke-LKDeviceAction'
            'Show-LKPolicyDetail'
        )

        $exportedFunctions = (Get-Module -Name IntuneLogicKit).ExportedFunctions.Keys
        foreach ($fn in $expectedFunctions) {
            $exportedFunctions | Should -Contain $fn
        }
    }

    It 'Should not export private functions' {
        $exportedFunctions = (Get-Module -Name IntuneLogicKit).ExportedFunctions.Keys
        $exportedFunctions | Should -Not -Contain 'Assert-LKSession'
        $exportedFunctions | Should -Not -Contain 'Invoke-LKGraphRequest'
        $exportedFunctions | Should -Not -Contain 'Resolve-LKGroupId'
        $exportedFunctions | Should -Not -Contain 'Resolve-LKMemberId'
        $exportedFunctions | Should -Not -Contain 'Get-LKPolicySettings'
        $exportedFunctions | Should -Not -Contain 'Invoke-LKGraphWithRetry'
    }
}

Describe 'Module requirements (issue #12)' {
    BeforeAll {
        $manifest = Import-PowerShellDataFile "$PSScriptRoot\..\IntuneLogicKit\IntuneLogicKit.psd1"
    }

    It 'Requires PowerShell 7.0 or later' {
        $manifest.PowerShellVersion | Should -Be '7.0'
    }

    It 'Targets the PowerShell Core edition' {
        $manifest.CompatiblePSEditions | Should -Contain 'Core'
    }
}

Describe 'Session state' {
    It 'Should initialize with Connected = false' {
        Get-LKSession 3>&1 | Should -BeLike '*No active session*'
    }
}

Describe 'Test-LKNameMatch (via module internals)' {
    BeforeAll {
        # Access the private function via the module scope
        $module = Get-Module IntuneLogicKit
        $testMatch = & $module { Get-Command Test-LKNameMatch }
    }

    It 'Contains match should find substring' {
        $result = & $module { Test-LKNameMatch -Value 'XW365 - Baseline Policy' -Name 'Baseline' -NameMatch Contains }
        $result | Should -BeTrue
    }

    It 'Contains match should be case-insensitive' {
        $result = & $module { Test-LKNameMatch -Value 'XW365 - Baseline Policy' -Name 'baseline' -NameMatch Contains }
        $result | Should -BeTrue
    }

    It 'Exact match should require full string' {
        $result = & $module { Test-LKNameMatch -Value 'Baseline Policy' -Name 'Baseline' -NameMatch Exact }
        $result | Should -BeFalse
    }

    It 'Exact match should succeed on full match' {
        $result = & $module { Test-LKNameMatch -Value 'Baseline Policy' -Name 'Baseline Policy' -NameMatch Exact }
        $result | Should -BeTrue
    }

    It 'Wildcard match should work with asterisks' {
        $result = & $module { Test-LKNameMatch -Value 'XW365 - Firewall' -Name 'XW365*' -NameMatch Wildcard }
        $result | Should -BeTrue
    }

    It 'Regex match should work with patterns' {
        $result = & $module { Test-LKNameMatch -Value 'Policy-V2-Final' -Name 'V\d+' -NameMatch Regex }
        $result | Should -BeTrue
    }

    It 'Should return false when no match found' {
        $result = & $module { Test-LKNameMatch -Value 'Production Policy' -Name 'Staging' -NameMatch Contains }
        $result | Should -BeFalse
    }

    It 'Should match any of multiple name patterns' {
        $result = & $module { Test-LKNameMatch -Value 'Firewall Policy' -Name @('Baseline', 'Firewall') -NameMatch Contains }
        $result | Should -BeTrue
    }
}

Describe 'Policy type registry' {
    BeforeAll {
        $module = Get-Module IntuneLogicKit
        $types = & $module { $script:LKPolicyTypes }
    }

    It 'Should have 16 policy types registered' {
        $types.Count | Should -Be 16
    }

    It 'Each type should have required keys' {
        foreach ($type in $types) {
            $type.TypeName       | Should -Not -BeNullOrEmpty
            $type.DisplayName    | Should -Not -BeNullOrEmpty
            $type.Endpoint       | Should -Not -BeNullOrEmpty
            $type.ApiVersion     | Should -BeIn @('v1.0', 'beta')
            $type.NameProperty   | Should -Not -BeNullOrEmpty
            $type.TargetScope    | Should -BeIn @('User', 'Device', 'Both')
            $type.AssignmentMethod | Should -BeIn @('Standard', 'GroupAssignments')
        }
    }

    It 'Should have unique TypeName values' {
        $typeNames = $types | ForEach-Object { $_.TypeName }
        ($typeNames | Select-Object -Unique).Count | Should -Be $typeNames.Count
    }
}

Describe 'Required scopes' {
    BeforeAll {
        $module = Get-Module IntuneLogicKit
        $scopes = & $module { $script:LKRequiredScopes }
    }

    It 'Should define required scopes' {
        $scopes | Should -Not -BeNullOrEmpty
        $scopes.Count | Should -BeGreaterThan 0
    }

    It 'Should include core Intune scopes' {
        $scopes | Should -Contain 'DeviceManagementConfiguration.ReadWrite.All'
        $scopes | Should -Contain 'DeviceManagementManagedDevices.ReadWrite.All'
    }
}

Describe 'Functions requiring session should throw without one' {
    It 'Get-LKPolicy should throw without session' {
        { Get-LKPolicy } | Should -Throw '*No active session*'
    }

    It 'Get-LKDevice should throw without session' {
        { Get-LKDevice } | Should -Throw '*No active session*'
    }

    It 'Get-LKGroup should throw without session' {
        { Get-LKGroup } | Should -Throw '*No active session*'
    }

    It 'Get-LKUser should throw without session' {
        { Get-LKUser } | Should -Throw '*No active session*'
    }
}

Describe 'Read-only session (issue #13)' {
    BeforeAll {
        $module = Get-Module IntuneLogicKit
    }

    Context 'Read-only scope set' {
        It 'Defines a read-only scope set' {
            $ro = & $module { $script:LKReadOnlyScopes }
            $ro | Should -Not -BeNullOrEmpty
        }
        It 'Requests no ReadWrite scopes' {
            $ro = & $module { $script:LKReadOnlyScopes }
            @($ro | Where-Object { $_ -like '*ReadWrite*' }) | Should -BeNullOrEmpty
        }
        It 'Covers the same number of services as the write scope set' {
            $rw = & $module { $script:LKRequiredScopes }
            $ro = & $module { $script:LKReadOnlyScopes }
            $ro.Count | Should -Be $rw.Count
        }
    }

    Context 'Assert-LKSession -RequireWrite' {
        AfterEach {
            InModuleScope IntuneLogicKit { $script:LKSession.Connected = $false; $script:LKSession.ReadOnly = $false }
        }

        It 'Throws on a read-only session' {
            InModuleScope IntuneLogicKit {
                Mock Get-MgContext { @{ TenantId = 't1'; Account = 'a1' } }
                $script:LKSession = @{ Connected = $true; TenantId = 't1'; TenantName = 'T'; Account = 'a1'; ReadOnly = $true }
                { Assert-LKSession -RequireWrite } | Should -Throw '*read-only*'
            }
        }

        It 'Permits reads on a read-only session' {
            InModuleScope IntuneLogicKit {
                Mock Get-MgContext { @{ TenantId = 't1'; Account = 'a1' } }
                $script:LKSession = @{ Connected = $true; TenantId = 't1'; TenantName = 'T'; Account = 'a1'; ReadOnly = $true }
                { Assert-LKSession } | Should -Not -Throw
            }
        }

        It 'Permits writes on a normal session' {
            InModuleScope IntuneLogicKit {
                Mock Get-MgContext { @{ TenantId = 't1'; Account = 'a1' } }
                $script:LKSession = @{ Connected = $true; TenantId = 't1'; TenantName = 'T'; Account = 'a1'; ReadOnly = $false }
                { Assert-LKSession -RequireWrite } | Should -Not -Throw
            }
        }
    }

    Context 'Every Graph-mutating command is guarded' {
        It '<Command> calls Assert-LKSession -RequireWrite' -TestCases @(
            @{ Command = 'Add-LKPolicyAssignment' }
            @{ Command = 'Remove-LKPolicyAssignment' }
            @{ Command = 'Add-LKPolicyExclusion' }
            @{ Command = 'Remove-LKPolicyExclusion' }
            @{ Command = 'Copy-LKPolicyAssignment' }
            @{ Command = 'Rename-LKPolicy' }
            @{ Command = 'New-LKGroup' }
            @{ Command = 'Remove-LKGroup' }
            @{ Command = 'Rename-LKGroup' }
            @{ Command = 'Add-LKGroupMember' }
            @{ Command = 'Remove-LKGroupMember' }
            @{ Command = 'Invoke-LKDeviceAction' }
        ) {
            param($Command)
            (Get-Command $Command).Definition | Should -BeLike '*Assert-LKSession -RequireWrite*'
        }
    }
}

Describe 'Resolve-LKGroupScope: empty assigned group fallback (issue #5)' {
    # Regression coverage for issue #5. An assigned (non-dynamic) group with no
    # members must still resolve its scope from the U/D/C tokens in its display
    # name instead of returning 'Unknown'. The name heuristic must stay reachable
    # for empty groups - it must not be gated behind an early 'Unknown' return.

    It 'Empty group with a -U- name token resolves to User' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                if ($Uri -like '*/members/*') { return [pscustomobject]@{ value = @() } }
                return [pscustomobject]@{
                    displayName                   = 'SG-Intune-U-Empty Test'
                    membershipRule                = $null
                    membershipRuleProcessingState = 'Off'
                    groupTypes                    = @()
                }
            }
            Resolve-LKGroupScope -GroupId '00000000-0000-0000-0000-0000000000a1' |
                Should -Be 'User'
        }
    }

    It 'Empty group with a -D- name token resolves to Device' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                if ($Uri -like '*/members/*') { return [pscustomobject]@{ value = @() } }
                return [pscustomobject]@{
                    displayName                   = 'SG-Intune-D-Empty Test'
                    membershipRule                = $null
                    membershipRuleProcessingState = 'Off'
                    groupTypes                    = @()
                }
            }
            Resolve-LKGroupScope -GroupId '00000000-0000-0000-0000-0000000000a2' |
                Should -Be 'Device'
        }
    }

    It 'Empty group with a -C- name token resolves to Device' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                if ($Uri -like '*/members/*') { return [pscustomobject]@{ value = @() } }
                return [pscustomobject]@{
                    displayName                   = 'SG-Intune-C-Empty Test'
                    membershipRule                = $null
                    membershipRuleProcessingState = 'Off'
                    groupTypes                    = @()
                }
            }
            Resolve-LKGroupScope -GroupId '00000000-0000-0000-0000-0000000000a3' |
                Should -Be 'Device'
        }
    }

    It 'Empty group whose name carries no scope token resolves to Unknown' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                if ($Uri -like '*/members/*') { return [pscustomobject]@{ value = @() } }
                return [pscustomobject]@{
                    displayName                   = 'Marketing Team'
                    membershipRule                = $null
                    membershipRuleProcessingState = 'Off'
                    groupTypes                    = @()
                }
            }
            Resolve-LKGroupScope -GroupId '00000000-0000-0000-0000-0000000000a4' |
                Should -Be 'Unknown'
        }
    }

    It 'Actual members take precedence over a misleading name token' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                if ($Uri -like '*/members/microsoft.graph.user*') {
                    return [pscustomobject]@{ value = @([pscustomobject]@{ id = 'u1' }) }
                }
                if ($Uri -like '*/members/*') { return [pscustomobject]@{ value = @() } }
                return [pscustomobject]@{
                    displayName                   = 'SG-Intune-D-Mislabeled'
                    membershipRule                = $null
                    membershipRuleProcessingState = 'Off'
                    groupTypes                    = @()
                }
            }
            Resolve-LKGroupScope -GroupId '00000000-0000-0000-0000-0000000000a5' |
                Should -Be 'User'
        }
    }
}

Describe 'Resolve-LKPolicyScope: ADMX class-aware scope (issue #3)' {
    # Regression coverage for issue #3. A GroupPolicyConfiguration (ADMX) policy
    # must resolve its scope from ALL of its definition values, not just the
    # first one. A policy mixing 'user' and 'machine' class settings is valid
    # against either target and must resolve to 'Both' so the assignment audit
    # does not flag (and a remediation loop does not strip) legitimate
    # user-group assignments.

    BeforeEach {
        # Every test starts with an empty ADMX class cache.
        InModuleScope IntuneLogicKit { $script:LKAdmxClassCache = @{} }
    }

    It 'Mixed user + machine ADMX policy resolves to Both' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                @(
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'user' } }
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'machine' } }
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'user' } }
                )
            }
            $policyType = @{ TypeName = 'GroupPolicyConfiguration'; TargetScope = 'Both'; NameProperty = 'displayName' }
            $rawPolicy  = [pscustomobject]@{ id = 'admx-mixed-1'; displayName = 'IE Trusted sites' }
            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType |
                Should -Be 'Both'
        }
    }

    It 'ADMX policy with only user-class settings resolves to User' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                @(
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'user' } }
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'user' } }
                )
            }
            $policyType = @{ TypeName = 'GroupPolicyConfiguration'; TargetScope = 'Both'; NameProperty = 'displayName' }
            $rawPolicy  = [pscustomobject]@{ id = 'admx-user-1'; displayName = 'OneDrive for Business' }
            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType |
                Should -Be 'User'
        }
    }

    It 'ADMX policy with only machine-class settings resolves to Device' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                @(
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'machine' } }
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'machine' } }
                )
            }
            $policyType = @{ TypeName = 'GroupPolicyConfiguration'; TargetScope = 'Both'; NameProperty = 'displayName' }
            $rawPolicy  = [pscustomobject]@{ id = 'admx-machine-1'; displayName = 'Defender Settings' }
            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType |
                Should -Be 'Device'
        }
    }

    It 'ADMX policy with no definition values falls through to the name heuristic' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest { @() }
            $policyType = @{ TypeName = 'GroupPolicyConfiguration'; TargetScope = 'Both'; NameProperty = 'displayName' }
            $rawPolicy  = [pscustomobject]@{ id = 'admx-empty-1'; displayName = 'Contoso - U - Settings' }
            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType |
                Should -Be 'User'
        }
    }

    It 'Definition values are fetched once per policy and cached' {
        InModuleScope IntuneLogicKit {
            Mock Invoke-LKGraphRequest {
                @(
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'user' } }
                    [pscustomobject]@{ definition = [pscustomobject]@{ classType = 'machine' } }
                )
            }
            $policyType = @{ TypeName = 'GroupPolicyConfiguration'; TargetScope = 'Both'; NameProperty = 'displayName' }
            $rawPolicy  = [pscustomobject]@{ id = 'admx-cache-1'; displayName = 'Cached Policy' }

            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType | Should -Be 'Both'
            Resolve-LKPolicyScope -RawPolicy $rawPolicy -PolicyType $policyType | Should -Be 'Both'

            Should -Invoke Invoke-LKGraphRequest -Exactly -Times 1
        }
    }
}

Describe 'Add/Remove-LKPolicyAssignment: broad targets (issue #1)' {
    # Coverage for issue #1: -AllDevices / -AllLicensedUsers switches on
    # Add-LKPolicyAssignment and Remove-LKPolicyAssignment.

    BeforeEach {
        Mock Assert-LKSession      -ModuleName IntuneLogicKit { }
        Mock Write-LKActionSummary -ModuleName IntuneLogicKit { }
        Mock Set-LKRawAssignment   -ModuleName IntuneLogicKit { }
        # A broad target must never trigger group resolution.
        Mock Resolve-LKGroupId     -ModuleName IntuneLogicKit { throw 'Resolve-LKGroupId should not be called for a broad target.' }
    }

    It 'Add throws when -AllDevices and -AllLicensedUsers are combined' {
        { Add-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -AllDevices -AllLicensedUsers -Confirm:$false } |
            Should -Throw '*mutually exclusive*'
    }

    It 'Add throws when no assignment target is given' {
        { Add-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -Confirm:$false } |
            Should -Throw '*assignment target is required*'
    }

    It 'Add -AllDevices builds an allDevices target with no groupId and no group lookup' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit { @() }

        Add-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -AllDevices -Confirm:$false

        Should -Invoke Resolve-LKGroupId -ModuleName IntuneLogicKit -Times 0 -Exactly
        Should -Invoke Set-LKRawAssignment -ModuleName IntuneLogicKit -Times 1 -Exactly -ParameterFilter {
            $Assignments.Count -eq 1 -and
            $Assignments[0].target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget' -and
            -not $Assignments[0].target.ContainsKey('groupId')
        }
    }

    It 'Add -AllLicensedUsers builds an allLicensedUsers target' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit { @() }

        Add-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -AllLicensedUsers -Confirm:$false

        Should -Invoke Set-LKRawAssignment -ModuleName IntuneLogicKit -Times 1 -Exactly -ParameterFilter {
            $Assignments[0].target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget'
        }
    }

    It 'Add -AllLicensedUsers on a Device-scoped policy is skipped by the scope check' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit { @() }

        Add-LKPolicyAssignment -PolicyId 'p1' -PolicyType Remediation -AllLicensedUsers -Confirm:$false -WarningAction SilentlyContinue

        Should -Invoke Set-LKRawAssignment -ModuleName IntuneLogicKit -Times 0 -Exactly
    }

    It 'Remove throws when no assignment target is given' {
        { Remove-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -Confirm:$false } |
            Should -Throw '*assignment target is required*'
    }

    It 'Remove -AllDevices drops only the all-devices target' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit {
            @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } }
                @{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = 'g1' } }
            )
        }

        Remove-LKPolicyAssignment -PolicyId 'p1' -PolicyType SettingsCatalog -AllDevices -Confirm:$false

        Should -Invoke Resolve-LKGroupId -ModuleName IntuneLogicKit -Times 0 -Exactly
        Should -Invoke Set-LKRawAssignment -ModuleName IntuneLogicKit -Times 1 -Exactly -ParameterFilter {
            $Assignments.Count -eq 1 -and
            $Assignments[0].target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'
        }
    }
}

Describe 'Get-LKGroupAssignment -Effective: per-scope assessment (issue #4)' {
    # Regression coverage for issue #4. -Effective collapses the per-group rows
    # into one row per policy and applies per-scope Exclude-wins: a user-group
    # Exclude cancels only the user delivery path, a device-group Exclude only
    # the device path. The switch and its logic landed in v0.5.0.

    BeforeEach {
        Mock Assert-LKSession -ModuleName IntuneLogicKit { }
        Mock Write-Host       -ModuleName IntuneLogicKit { }
        Mock Get-LKGroup      -ModuleName IntuneLogicKit {
            @(
                [pscustomobject]@{ Id = 'u1'; Name = 'SG-Intune-U-Pilot Users' }
                [pscustomobject]@{ Id = 'd1'; Name = 'SG-Intune-D-Pilot Devices' }
            )
        }
        Mock Resolve-LKGroupScope -ModuleName IntuneLogicKit {
            switch ($GroupId) { 'u1' { 'User' } 'd1' { 'Device' } default { 'Unknown' } }
        }
        Mock Invoke-LKGraphRequest -ModuleName IntuneLogicKit {
            @( @{ id = 'p1'; displayName = 'Compliance - Baseline' } )
        }
    }

    It 'A device-group Exclude does not cancel user-group delivery' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit {
            @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget';          groupId = 'u1' } }
                @{ target = @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = 'd1' } }
            )
        }

        $result = Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users', 'SG-Intune-D-Pilot Devices' `
            -NameMatch Exact -PolicyType CompliancePolicy -SkipScopeResolution -Effective

        $result.EffectiveState | Should -Be 'Applied'
        $result.UserPath       | Should -Be 'Include:SG-Intune-U-Pilot Users'
        $result.DevicePath     | Should -Be 'Excluded:SG-Intune-D-Pilot Devices'
    }

    It 'A user-group Exclude with no Include yields Excluded' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit {
            @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = 'u1' } }
            )
        }

        $result = Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users', 'SG-Intune-D-Pilot Devices' `
            -NameMatch Exact -PolicyType CompliancePolicy -SkipScopeResolution -Effective

        $result.EffectiveState | Should -Be 'Excluded'
        $result.UserPath       | Should -Be 'Excluded:SG-Intune-U-Pilot Users'
        $result.DevicePath     | Should -Be '-'
    }

    It 'An All Devices broad target delivers on the device-scope path only' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit {
            @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } }
            )
        }

        $result = Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users', 'SG-Intune-D-Pilot Devices' `
            -NameMatch Exact -PolicyType CompliancePolicy -SkipScopeResolution -Effective

        $result.EffectiveState | Should -Be 'Applied'
        $result.UserPath       | Should -Be '-'
        $result.DevicePath     | Should -Be 'AllDevices'
    }

    It '-AppliedOnly drops policies that are not delivered' {
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit {
            @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = 'u1' } }
            )
        }

        $result = Get-LKGroupAssignment -Name 'SG-Intune-U-Pilot Users', 'SG-Intune-D-Pilot Devices' `
            -NameMatch Exact -PolicyType CompliancePolicy -SkipScopeResolution -Effective -AppliedOnly

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-LKGroupAssignment: bulk app assignment fetch (issue #15)' {
    # Apps are fetched with $expand=assignments in one paged call. Assignments
    # arrive inline, so Get-LKRawAssignment must NOT be invoked per app.

    BeforeEach {
        Mock Assert-LKSession -ModuleName IntuneLogicKit { }
        Mock Write-Host       -ModuleName IntuneLogicKit { }
        Mock Get-LKGroup      -ModuleName IntuneLogicKit {
            @( [pscustomobject]@{ Id = 'd1'; Name = 'SG-Intune-D-Pilot Devices' } )
        }
        # Single-name Exact routes through Resolve-LKGroupId - mock it so the
        # Invoke-LKGraphRequest mock below is used only for the policy fetch.
        Mock Resolve-LKGroupId    -ModuleName IntuneLogicKit { 'd1' }
        Mock Resolve-LKGroupScope -ModuleName IntuneLogicKit { 'Device' }
        # Apps with assignments inlined via $expand
        Mock Invoke-LKGraphRequest -ModuleName IntuneLogicKit {
            @(
                @{
                    id            = 'app1'
                    displayName   = 'Contoso Android App'
                    '@odata.type' = '#microsoft.graph.androidStoreApp'
                    assignments   = @(
                        @{ intent = 'required'; target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = 'd1' } }
                    )
                }
                @{
                    id            = 'app2'
                    displayName   = 'Contoso iOS App'
                    '@odata.type' = '#microsoft.graph.iosStoreApp'
                    assignments   = @(
                        @{ intent = 'available'; target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = 'other' } }
                    )
                }
            )
        }
        Mock Get-LKRawAssignment -ModuleName IntuneLogicKit { @() }
    }

    It 'Reads inline assignments and finds the group without per-app calls' {
        $result = @(Get-LKGroupAssignment -Name 'SG-Intune-D-Pilot Devices' `
                -NameMatch Exact -PolicyType App -SkipScopeResolution)

        $result.Count            | Should -Be 1
        $result[0].PolicyName    | Should -Be 'Contoso Android App'
        $result[0].AssignmentType | Should -Be 'Include'
        $result[0].Intent        | Should -Be 'required'

        Should -Invoke Get-LKRawAssignment -ModuleName IntuneLogicKit -Times 0 -Exactly
    }

    It 'Requests the apps endpoint with $expand=assignments' {
        Get-LKGroupAssignment -Name 'SG-Intune-D-Pilot Devices' `
            -NameMatch Exact -PolicyType App -SkipScopeResolution | Out-Null

        Should -Invoke Invoke-LKGraphRequest -ModuleName IntuneLogicKit -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*mobileApps?$expand=assignments*'
        }
    }

    It 'Honors -Platform alongside the bulk fetch' {
        $result = @(Get-LKGroupAssignment -Name 'SG-Intune-D-Pilot Devices' `
                -NameMatch Exact -PolicyType App -Platform iOS -SkipScopeResolution)

        # Only the iOS app is considered; it targets 'other', not our group -> no rows
        $result.Count | Should -Be 0
    }
}

Describe 'Resolve-LKAppPlatform: @odata.type -> platform (issue #14)' {
    BeforeAll {
        $module = Get-Module IntuneLogicKit
    }

    It 'Maps <ODataType> to <Expected>' -TestCases @(
        # Android
        @{ ODataType = '#microsoft.graph.androidStoreApp';            Expected = 'Android' }
        @{ ODataType = '#microsoft.graph.androidManagedStoreApp';     Expected = 'Android' }
        @{ ODataType = '#microsoft.graph.managedAndroidStoreApp';     Expected = 'Android' }
        @{ ODataType = '#microsoft.graph.androidForWorkApp';          Expected = 'Android' }
        # iOS
        @{ ODataType = '#microsoft.graph.iosStoreApp';                Expected = 'iOS' }
        @{ ODataType = '#microsoft.graph.iosVppApp';                  Expected = 'iOS' }
        @{ ODataType = '#microsoft.graph.managedIOSStoreApp';         Expected = 'iOS' }
        # macOS - must win over shared keywords (Office/Edge/VPP)
        @{ ODataType = '#microsoft.graph.macOSDmgApp';                Expected = 'macOS' }
        @{ ODataType = '#microsoft.graph.macOSOfficeSuiteApp';        Expected = 'macOS' }
        @{ ODataType = '#microsoft.graph.macOSMicrosoftEdgeApp';      Expected = 'macOS' }
        @{ ODataType = '#microsoft.graph.macOSVppApp';                Expected = 'macOS' }
        # Windows
        @{ ODataType = '#microsoft.graph.win32LobApp';                Expected = 'Windows' }
        @{ ODataType = '#microsoft.graph.winGetApp';                  Expected = 'Windows' }
        @{ ODataType = '#microsoft.graph.officeSuiteApp';             Expected = 'Windows' }
        @{ ODataType = '#microsoft.graph.microsoftStoreForBusinessApp'; Expected = 'Windows' }
        @{ ODataType = '#microsoft.graph.windowsMicrosoftEdgeApp';    Expected = 'Windows' }
        # windowsWebApp must resolve to Windows, not Web
        @{ ODataType = '#microsoft.graph.windowsWebApp';              Expected = 'Windows' }
        # Web (generic clip)
        @{ ODataType = '#microsoft.graph.webApp';                     Expected = 'Web' }
    ) {
        param($ODataType, $Expected)
        $result = & $module { param($t) Resolve-LKAppPlatform -ODataType $t } $ODataType
        $result | Should -Be $Expected
    }

    It 'Returns $null for an unrecognized type' {
        $result = & $module { param($t) Resolve-LKAppPlatform -ODataType $t } '#microsoft.graph.someFutureUnknownApp'
        $result | Should -BeNullOrEmpty
    }
}

AfterAll {
    Remove-Module -Name IntuneLogicKit -ErrorAction SilentlyContinue
}
