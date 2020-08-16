# Bootstrap dependencies

# Avoid progress bar artefacts on reports
$ProgressPreference = 'SilentlyContinue'

# Fail on error
$ErrorActionPreference = 'Stop'

# https://docs.microsoft.com/powershell/module/packagemanagement/get-packageprovider
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null

# https://docs.microsoft.com/powershell/module/powershellget/set-psrepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

#Include: Settings
$moduleName = 'Arquebuse'
$moduleSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "$moduleName.Settings.ps1"
. $moduleSettingsPath

'Installing PowerShell Modules'
foreach ($module in $requiredModules) {
    $installSplat = @{
        Name            = $module.ModuleName
        RequiredVersion = $module.ModuleVersion
        Repository      = 'PSGallery'
        Force           = $true
        ErrorAction     = 'Stop'
    }
    try {
        Install-Module @installSplat
        Import-Module -Name $module.ModuleName -RequiredVersion $module.ModuleVersion -Force

        '  - Successfully installed {0} version {1}' -f $module.ModuleName, $(get-module -Name $module.ModuleName).Version.ToString()
    }
    catch {
        $message = 'Failed to install {0}' -f $module.ModuleName
        "  - $message"
        throw $message
    }
}
