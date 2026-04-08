$policyNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $script:LKPolicyNameCache | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object | ForEach-Object {
        $text = if ($_ -match '\s') { "'$_'" } else { $_ }
        [System.Management.Automation.CompletionResult]::new($text, $_, 'ParameterValue', $_)
    }
}

$groupNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $script:LKGroupNameCache | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object | ForEach-Object {
        $text = if ($_ -match '\s') { "'$_'" } else { $_ }
        [System.Management.Automation.CompletionResult]::new($text, $_, 'ParameterValue', $_)
    }
}

# Policy name parameters
@(
    @{ Command = 'Get-LKPolicy';                Parameter = 'Name' }
    @{ Command = 'Get-LKPolicyOverview';         Parameter = 'Name' }
    @{ Command = 'Test-LKPolicyAssignment';      Parameter = 'Name' }
    @{ Command = 'Add-LKPolicyAssignment';       Parameter = 'PolicyName' }
    @{ Command = 'Add-LKPolicyExclusion';        Parameter = 'PolicyName' }
    @{ Command = 'Remove-LKPolicyAssignment';    Parameter = 'PolicyName' }
    @{ Command = 'Remove-LKPolicyExclusion';     Parameter = 'PolicyName' }
    @{ Command = 'Search-LKSetting';             Parameter = 'PolicyName' }
) | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_.Command -ParameterName $_.Parameter -ScriptBlock $policyNameCompleter
}

# Group name parameters
@(
    @{ Command = 'Get-LKGroup';                  Parameter = 'Name' }
    @{ Command = 'Get-LKGroupAssignment';        Parameter = 'Name' }
    @{ Command = 'Get-LKGroupMember';            Parameter = 'GroupName' }
    @{ Command = 'Add-LKGroupMember';            Parameter = 'GroupName' }
    @{ Command = 'Remove-LKGroupMember';         Parameter = 'GroupName' }
    @{ Command = 'Add-LKPolicyAssignment';       Parameter = 'GroupName' }
    @{ Command = 'Add-LKPolicyExclusion';        Parameter = 'GroupName' }
    @{ Command = 'Remove-LKPolicyAssignment';    Parameter = 'GroupName' }
    @{ Command = 'Remove-LKPolicyExclusion';     Parameter = 'GroupName' }
    @{ Command = 'Copy-LKPolicyAssignment';      Parameter = 'SourceGroup' }
    @{ Command = 'Copy-LKPolicyAssignment';      Parameter = 'TargetGroup' }
    @{ Command = 'Rename-LKGroup';               Parameter = 'Name' }
) | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_.Command -ParameterName $_.Parameter -ScriptBlock $groupNameCompleter
}
