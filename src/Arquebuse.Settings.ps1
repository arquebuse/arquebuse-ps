
# List of PowerShell Modules required for the build
$requiredModules = [System.Collections.ArrayList]::new()

# https://github.com/pester/Pester
$null = $requiredModules.Add(([PSCustomObject]@{
            ModuleName    = 'Pester'
            ModuleVersion = '4.9.0'
        }))
# https://github.com/nightroman/Invoke-Build
$null = $requiredModules.Add(([PSCustomObject]@{
            ModuleName    = 'InvokeBuild'
            ModuleVersion = '5.6.0'
        }))
# https://github.com/PowerShell/PSScriptAnalyzer
$null = $requiredModules.Add(([PSCustomObject]@{
            ModuleName    = 'PSScriptAnalyzer'
            ModuleVersion = '1.19.0'
        }))
# https://github.com/PowerShell/platyPS
# older version used due to: https://github.com/PowerShell/platyPS/issues/457
$null = $requiredModules.Add(([PSCustomObject]@{
            ModuleName    = 'platyPS'
            ModuleVersion = '0.12.0'
        }))