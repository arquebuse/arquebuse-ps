# Bootstrap dependencies

# Avoid progress bar artefacts on reports
$ProgressPreference = 'SilentlyContinue'

# https://docs.microsoft.com/powershell/module/packagemanagement/get-packageprovider
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null

# https://docs.microsoft.com/powershell/module/powershellget/set-psrepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

#Include: Settings
$ModuleName = 'Arquebuse'
. "./$ModuleName.Settings.ps1"

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
        Import-Module -Name $module.ModuleName -ErrorAction Stop -RequiredVersion $module.ModuleVersion -Force

        '  - Successfully installed {0} version {1}' -f $module.ModuleName, $(get-module -Name $module.ModuleName).Version.ToString()
    }
    catch {
        $message = 'Failed to install {0}' -f $module.ModuleName
        "  - $message"
        throw $message
    }
}
