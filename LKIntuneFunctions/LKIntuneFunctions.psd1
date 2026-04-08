@{
    RootModule        = 'LKIntuneFunctions.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f7b2c1-9d4e-4a8f-b6e5-1c3d7f9a2b4e'
    Author            = 'Jesper Nordkvist'
    Description       = 'Intune Logic Kit - PowerShell module for Intune management via Microsoft Graph.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
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
        'Test-LKPolicyAssignment'
        'Get-LKPolicyOverview'
        'Update-LKModule'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Intune', 'MEM', 'EndpointManager')
            ProjectUri = 'https://github.com/JesperNordkvist/LKIntuneFunctions'
        }
    }
}
