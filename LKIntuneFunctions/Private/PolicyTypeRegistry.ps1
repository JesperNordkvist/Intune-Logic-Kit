$script:LKPolicyTypes = @(
    @{
        TypeName         = 'DeviceConfiguration'
        DisplayName      = 'Device Configuration Profile'
        Endpoint         = '/deviceManagement/deviceConfigurations'
        ApiVersion       = 'v1.0'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'SettingsCatalog'
        DisplayName      = 'Settings Catalog Policy'
        Endpoint         = '/deviceManagement/configurationPolicies'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'name'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'CompliancePolicy'
        DisplayName      = 'Compliance Policy'
        Endpoint         = '/deviceManagement/deviceCompliancePolicies'
        ApiVersion       = 'v1.0'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'EndpointSecurity'
        DisplayName      = 'Endpoint Security Policy'
        Endpoint         = '/deviceManagement/intents'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'AppProtectionIOS'
        DisplayName      = 'App Protection Policy (iOS)'
        Endpoint         = '/deviceAppManagement/iosManagedAppProtections'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'User'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'AppProtectionAndroid'
        DisplayName      = 'App Protection Policy (Android)'
        Endpoint         = '/deviceAppManagement/androidManagedAppProtections'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'User'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'AppProtectionWindows'
        DisplayName      = 'App Protection Policy (Windows)'
        Endpoint         = '/deviceAppManagement/windowsManagedAppProtections'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'User'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'AppConfiguration'
        DisplayName      = 'App Configuration Policy'
        Endpoint         = '/deviceAppManagement/mobileAppConfigurations'
        ApiVersion       = 'v1.0'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'EnrollmentConfiguration'
        DisplayName      = 'Enrollment Configuration'
        Endpoint         = '/deviceManagement/deviceEnrollmentConfigurations'
        ApiVersion       = 'v1.0'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'PolicySet'
        DisplayName      = 'Policy Set'
        Endpoint         = '/deviceAppManagement/policySets'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'GroupPolicyConfiguration'
        DisplayName      = 'Group Policy Configuration (ADMX)'
        Endpoint         = '/deviceManagement/groupPolicyConfigurations'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'PlatformScript'
        DisplayName      = 'Platform Script'
        Endpoint         = '/deviceManagement/deviceManagementScripts'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Device'
        AssignmentMethod = 'GroupAssignments'
    }
    @{
        TypeName         = 'Remediation'
        DisplayName      = 'Remediation'
        Endpoint         = '/deviceManagement/deviceHealthScripts'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Device'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'DriverUpdate'
        DisplayName      = 'Driver Update Profile'
        Endpoint         = '/deviceManagement/windowsDriverUpdateProfiles'
        ApiVersion       = 'beta'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Device'
        AssignmentMethod = 'Standard'
    }
    @{
        TypeName         = 'App'
        DisplayName      = 'Application'
        Endpoint         = '/deviceAppManagement/mobileApps'
        ApiVersion       = 'v1.0'
        AssignmentPath   = '/assignments'
        NameProperty     = 'displayName'
        TargetScope      = 'Both'
        AssignmentMethod = 'Standard'
    }
)
