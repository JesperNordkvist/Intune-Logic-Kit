$script:LKReportTypes = @(
    # --- Device reports ---
    @{
        Name        = 'Devices'
        DisplayName = 'All managed devices'
        ReportName  = 'Devices'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'DeviceCompliance'
        DisplayName = 'Device compliance status'
        ReportName  = 'DeviceCompliance'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'DeviceNonCompliance'
        DisplayName = 'Non-compliant devices'
        ReportName  = 'DeviceNonCompliance'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'DevicesWithoutCompliancePolicy'
        DisplayName = 'Devices without a compliance policy'
        ReportName  = 'DevicesWithoutCompliancePolicy'
        Mode        = 'ExportJob'
    }

    # --- Configuration / policy reports ---
    @{
        Name        = 'ConfigurationPolicyNonCompliance'
        DisplayName = 'Configuration policy non-compliance by device'
        ReportName  = 'ConfigurationPolicyNonComplianceByDevice'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'ConfigurationPolicyNonComplianceSummary'
        DisplayName = 'Configuration policy non-compliance summary'
        ReportName  = 'ConfigurationPolicyNonComplianceSummary'
        Mode        = 'ExportJob'
    }

    # --- Proactive remediations ---
    @{
        Name              = 'ProactiveRemediation'
        DisplayName       = 'Proactive remediation device run states'
        ReportName        = 'DeviceRunStatesByProactiveRemediation'
        Mode              = 'ExportJob'
        RequiresPolicyId  = $true
        PolicyIdFilterFmt = "(PolicyId eq '{0}')"
        AcceptsPipeline   = 'Remediation'
    }

    # --- Platform scripts (direct endpoint — no exportJob report) ---
    @{
        Name            = 'PlatformScript'
        DisplayName     = 'Platform script device run states'
        Mode            = 'DirectEndpoint'
        RequiresPolicyId = $true
        Endpoint        = "/deviceManagement/deviceManagementScripts/{0}/deviceRunStates?`$expand=managedDevice"
        ApiVersion      = 'beta'
        AcceptsPipeline = 'PlatformScript'
    }

    # --- App reports ---
    @{
        Name              = 'AppInstallStatus'
        DisplayName       = 'App install status by device'
        ReportName        = 'DeviceInstallStatusByApp'
        Mode              = 'ExportJob'
        RequiresAppId     = $true
        AppIdFilterFmt    = "(ApplicationId eq '{0}')"
        AcceptsPipeline   = 'App'
    }
    @{
        Name              = 'AppInstallStatusByUser'
        DisplayName       = 'App install status by user'
        ReportName        = 'UserInstallStatusAggregateByApp'
        Mode              = 'ExportJob'
        RequiresAppId     = $true
        AppIdFilterFmt    = "(ApplicationId eq '{0}')"
        AcceptsPipeline   = 'App'
    }
    @{
        Name        = 'DetectedApps'
        DisplayName = 'Detected apps aggregate'
        ReportName  = 'DetectedAppsAggregate'
        Mode        = 'ExportJob'
    }

    # --- Security reports ---
    @{
        Name        = 'DefenderAgents'
        DisplayName = 'Microsoft Defender agent status'
        ReportName  = 'DefenderAgents'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'ActiveMalware'
        DisplayName = 'Active malware'
        ReportName  = 'ActiveMalware'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'Malware'
        DisplayName = 'All detected malware'
        ReportName  = 'Malware'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'FirewallStatus'
        DisplayName = 'Firewall status'
        ReportName  = 'FirewallStatus'
        Mode        = 'ExportJob'
    }
    @{
        Name        = 'Certificates'
        DisplayName = 'All device certificates'
        ReportName  = 'AllDeviceCertificates'
        Mode        = 'ExportJob'
    }
)
