<#
.SYNOPSIS
    An Invoke-Build Build file.
.DESCRIPTION
    Build steps can include:
        - Clean
        - ValidateRequirements
        - FormattingCheck
        - Analyze
        - Pester
        - CreateHelpStart
        - Build
        - InfraTest
        - Archive
.EXAMPLE
    Invoke-Build

    This will perform the default build Add-BuildTasks: see below for the default Add-BuildTask execution
.EXAMPLE
    Invoke-Build -Add-BuildTask Analyze,Pester

    This will perform only the Analyze and Pester Add-BuildTasks.
.NOTES
    This build will pull in configurations from the "<module>.Settings.ps1" file as well, where users can more easily customize the build process if required.
    The 'InstallDependencies' Add-BuildTask isn't present here. pre-requisite modules are installed at a previous step in the pipeline.
    https://github.com/nightroman/Invoke-Build
    https://github.com/nightroman/Invoke-Build/wiki/Build-Scripts-Guidelines
#>

$ErrorActionPreference = 'Stop'

#Include: Settings
$moduleName = 'Arquebuse'
$moduleSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "$moduleName.Settings.ps1"
. $moduleSettingsPath

# Load prerequisite modules
foreach ($module in $requiredModules) {
    Import-Module -Name $module.ModuleName -RequiredVersion $module.ModuleVersion -Force
}

#Default Build
$str = @()
$str = 'Clean', 'ValidateRequirements'
$str += 'CheckManifestVersion'
$str += 'FormattingCheck'
$str += 'Analyze', 'Pester'
$str += 'CreateHelpStart'
$str += 'Build', 'Archive'
Add-BuildTask -Name . -Jobs $str

#Syntax and formatting checks
Add-BuildTask Validate CheckManifestVersion, FormattingCheck, Analyze

#Local testing build process
Add-BuildTask TestLocal Clean, FormattingCheck, Analyze, Pester

#Local help file creation process
Add-BuildTask HelpLocal Clean, CreateHelpStart, UpdateCBH

# Pre-build variables to be used by other portions of the script
Enter-Build {
    $script:ModuleName = (Split-Path -Path $BuildFile -Leaf).Split('.')[0]

    # Identify other required paths
    $script:ModuleSourcePath = Join-Path -Path $BuildRoot -ChildPath $script:ModuleName
    $script:RootPath = Split-Path -Path $BuildRoot -Parent
    $script:ModuleFiles = Join-Path -Path $script:ModuleSourcePath -ChildPath '*'
    $script:ModuleManifestFile = Join-Path -Path $script:ModuleSourcePath -ChildPath "$($script:ModuleName).psd1"
    $script:ModuleChangelogFile = Join-Path -Path $script:RootPath -ChildPath 'CHANGELOG.md'
    $script:ModuleDocsPath = Join-Path -Path $script:RootPath -ChildPath 'docs'

    $manifestInfo = Import-PowerShellDataFile -Path $script:ModuleManifestFile
    $script:ModuleVersion = $manifestInfo.ModuleVersion
    $script:ModuleDescription = $manifestInfo.Description
    $Script:FunctionsToExport = $manifestInfo.FunctionsToExport

    $script:TestsPath = Join-Path -Path $BuildRoot -ChildPath 'Tests'
    $script:UnitTestsPath = Join-Path -Path $script:TestsPath -ChildPath 'Unit'
    $script:InfraTestsPath = Join-Path -Path $script:TestsPath -ChildPath 'Infrastructure'

    $script:ArtifactsPath = Join-Path -Path $BuildRoot -ChildPath 'Artifacts'
    $script:ArchivePath = Join-Path -Path $BuildRoot -ChildPath 'Archive'

    $script:BuildModuleRootFile = Join-Path -Path $script:ArtifactsPath -ChildPath "$($script:ModuleName).psm1"
}#Enter-Build

# Define headers as separator, task path, synopsis, and location, e.g. for Ctrl+Click in VSCode.
# Also change the default color to Green. If you need task start times, use `$Task.Started`.
Set-BuildHeader {
    param($Path)
    # separator line
    Write-Build DarkMagenta ('=' * 79)
    # default header + synopsis
    Write-Build DarkGray "Task $Path : $(Get-BuildSynopsis $Task)"
    # task location in a script
    Write-Build DarkGray "At $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"
    Write-Build Yellow "Manifest File: $script:ModuleManifestFile"
    Write-Build Yellow "Manifest Version: $($script:ModuleVersion)"
}#Set-BuildHeader

# Define footers similar to default but change the color to DarkGray.
Set-BuildFooter {
    param($Path)
    Write-Build DarkGray "Done $Path, $($Task.Elapsed)"
    # # separator line
    # Write-Build Gray ('=' * 79)
}#Set-BuildFooter

#Synopsis: Clean and reset Artifacts/Archive Directory
Add-BuildTask Clean {
    Write-Build White 'Clean up our Artifacts/Archive directory...'

    $null = Remove-Item $script:ArtifactsPath -Force -Recurse -ErrorAction 0
    $null = New-Item $script:ArtifactsPath -ItemType:Directory
    $null = Remove-Item $script:ArchivePath -Force -Recurse -ErrorAction 0
    $null = New-Item $script:ArchivePath -ItemType:Directory

    Write-Build Green 'Clean Complete!'
}#Clean

#Synopsis: Validate system requirements are met
Add-BuildTask ValidateRequirements {
    #running at least powershell 5?
    Write-Build White 'Verifying at least PowerShell 5...'
    Assert-Build ($PSVersionTable.PSVersion.Major.ToString() -ge '5') 'At least Powershell 5 is required for this build to function properly'
    Write-Build Green 'Verification Complete!'
}#ValidateRequirements

#Synopsis: Check if the last version in the changelog is the same as in the manifest
Add-BuildTask CheckManifestVersion {
    Write-Build White 'Verifying module manifest version...'
    # Get latest version in Changelog
    $changelog = Get-Content -Path $script:ModuleChangelogFile -Raw
    Assert-Build ($changelog -match '\[(?<Version>[0-9]+\.[0-9]+\.[0-9]+)\]') 'Cannot get latest version from changelog'
    $changelogVersion = $Matches['Version']

    Assert-Build ($script:ModuleVersion -eq $changelogVersion) 'Module version in the manifest is not the same as in the changelog. Please run Invoke-Build UpdateManifest.'
    Write-Build Green 'Module manifest version is up to date'
}#CheckManifestVersion

#Synopsis: Update module version in the manifest
Add-BuildTask UpdateManifest {
    Write-Build White 'Updating module manifest version...'
    # Get latest version in Changelog
    $changelog = Get-Content -Path $script:ModuleChangelogFile -Raw
    Assert-Build ($changelog -match '\[(?<Version>[0-9]+\.[0-9]+\.[0-9]+)\]') 'Cannot get latest version from changelog'
    $changelogVersion = $Matches['Version']

    $manifestContent = Get-Content -Path $script:ModuleManifestFile -Raw
    $manifestContent = $manifestContent -replace "ModuleVersion = '[^']+'", "ModuleVersion = '$changelogVersion'"
    $manifestContent | Set-Content -Path $script:ModuleManifestFile -Force -NoNewline -Encoding 'utf8BOM'
    Write-Build Green 'Module manifest version successfully updated'
}

#Synopsis: Invokes PSScriptAnalyzer against the Module source path
Add-BuildTask Analyze {

    $scriptAnalyzerParams = @{
        Path    = $script:ModuleSourcePath
        Setting = "PSScriptAnalyzerSettings.psd1"
        Recurse = $true
        Verbose = $false
    }

    Write-Build White 'Performing Module ScriptAnalyzer checks...'
    $scriptAnalyzerResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

    if ($scriptAnalyzerResults) {
        $scriptAnalyzerResults | Format-Table
        throw 'One or more PSScriptAnalyzer errors/warnings where found.'
    }
    else {
        Write-Build Green 'Module Analyze Complete!'
    }
}#Analyze

#Synopsis: Invokes Script Analyzer against the Tests path if it exists
Add-BuildTask AnalyzeTests -After Analyze {
    if (Test-Path -Path $script:TestsPath) {

        $scriptAnalyzerParams = @{
            Path    = $script:TestsPath
            Setting = "PSScriptAnalyzerSettings.psd1"
            Recurse = $true
            Verbose = $false
        }

        Write-Build White 'Performing Test ScriptAnalyzer checks...'
        $scriptAnalyzerResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

        if ($scriptAnalyzerResults) {
            $scriptAnalyzerResults | Format-Table
            throw 'One or more PSScriptAnalyzer errors/warnings where found.'
        }
        else {
            Write-Build Green 'Test Analyze Complete!'
        }
    }
}#AnalyzeTests

#Synopsis: Analyze scripts to verify if they adhere to desired coding format (Stroustrup / OTBS / Allman)
Add-BuildTask FormattingCheck {

    $scriptAnalyzerParams = @{
        Setting     = 'CodeFormattingOTBS'
        ExcludeRule = 'PSUseConsistentWhitespace'
        Recurse     = $true
        Verbose     = $false
    }

    Write-Build White 'Performing script formatting checks...'
    $scriptAnalyzerResults = Get-ChildItem -Path $script:ModuleSourcePath -Exclude "*.psd1" | Invoke-ScriptAnalyzer @scriptAnalyzerParams

    if ($scriptAnalyzerResults) {
        $scriptAnalyzerResults | Format-Table
        throw 'PSScriptAnalyzer code formatting check did not adhere to {0} standards' -f $scriptAnalyzerParams.Setting
    }
    else {
        Write-Build Green 'Formatting Analyze Complete!'
    }
}#FormattingCheck

#Synopsis: Invokes all Pester Unit Tests in the Tests\Unit folder (if it exists)
Add-BuildTask Pester {
    $codeCovPath = "$script:ArtifactsPath\ccReport\"
    if (-not(Test-Path $codeCovPath)) {
        New-Item -Path $codeCovPath -ItemType Directory | Out-Null
    }
    if (Test-Path -Path $script:UnitTestsPath) {
        $invokePesterParams = @{
            Path                   = 'Tests\Unit'
            Strict                 = $true
            PassThru               = $true
            Verbose                = $false
            EnableExit             = $false
            CodeCoverage           = "$moduleName\*\*.ps1"
            CodeCoverageOutputFile = "$codeCovPath\CodeCoverage.xml"
            # CodeCoverage                 = "$moduleName\*\*.ps1"
            # CodeCoverageOutputFile       = "$codeCovPath\codecoverage.xml"
            # CodeCoverageOutputFileFormat = 'JaCoCo'
        }

        Write-Build White 'Performing Pester Unit Tests...'
        # Publish Test Results as NUnitXml
        $testResults = Invoke-Pester @invokePesterParams

        # This will output a nice json for each failed test (if running in CodeBuild)
        if ($env:CODEBUILD_BUILD_ARN) {
            $testResults.TestResult | ForEach-Object {
                if ($_.Result -ne 'Passed') {
                    ConvertTo-Json -InputObject $_ -Compress
                }
            }
        }

        $numberFails = $testResults.FailedCount
        Assert-Build($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)

        # Ensure our builds fail until if below a minimum defined code test coverage threshold
        $coverageThreshold = 50

        if ($testResults.CodeCoverage.NumberOfCommandsExecuted -ne 0) {
            $coveragePercent = '{0:N2}' -f ($testResults.CodeCoverage.NumberOfCommandsExecuted / $testResults.CodeCoverage.NumberOfCommandsAnalyzed * 100)

            <#
            if ($testResults.CodeCoverage.NumberOfCommandsMissed -gt 0) {
                'Failed to analyze "{0}" commands' -f $testResults.CodeCoverage.NumberOfCommandsMissed
            }
            Write-Host "PowerShell Commands not tested:`n$(ConvertTo-Json -InputObject $testResults.CodeCoverage.MissedCommands)"
            #>
            if ([Int]$coveragePercent -lt $coverageThreshold) {
                throw ('Failed to meet code coverage threshold of {0}% with only {1}% coverage' -f $coverageThreshold, $coveragePercent)
            }
            else {
                Write-Build Cyan "$('Covered {0}% of {1} analyzed commands in {2} files.' -f $coveragePercent,$testResults.CodeCoverage.NumberOfCommandsAnalyzed,$testResults.CodeCoverage.NumberOfFilesAnalyzed)"
                Write-Build Green 'Pester Unit Tests Complete!'
            }
        }
        else {
            # account for new module build condition
            Write-Build Yellow 'Code coverage check skipped. No commands to execute...'
        }
    }
}#Test

#Synopsis: Used primarily during active development to generate xml file to graphically display code coverage in VSCode using Coverage Gutters
Add-BuildTask DevCC {
    Write-Build White 'Generating code coverage report at root...'
    $invokePesterParams = @{
        Path                   = 'Tests\Unit'
        CodeCoverage           = "$moduleName\*\*.ps1"
        CodeCoverageOutputFile = '..\..\..\cov.xml'
    }
    Invoke-Pester @invokePesterParams
    Write-Build Green 'Code Coverage report generated!'
}#DevCC

# Synopsis: Build help for module
Add-BuildTask CreateHelpStart {
    Write-Build White 'Performing all help related actions.'
}#CreateHelpStart

# Synopsis: Build markdown help files for module and fail if help information is missing
Add-BuildTask CreateMarkdownHelp -After CreateHelpStart {
    $ModulePage = "$($script:ArtifactsPath)\docs\$($moduleName).md"

    $markdownParams = @{
        Module         = $moduleName
        OutputFolder   = "$($script:ArtifactsPath)\docs\"
        Force          = $true
        WithModulePage = $true
        Locale         = 'en-US'
        FwLink         = "NA"
        HelpVersion    = $script:ModuleVersion
    }

    Write-Build Gray '     Generating markdown files...'
    $null = New-MarkdownHelp @markdownParams
    Write-Build Gray '     Markdown generation completed.'

    Write-Build Gray '     Replacing markdown elements...'
    # Replace multi-line EXAMPLES
    $OutputDir = "$($script:ArtifactsPath)\docs\"
    $OutputDir | Get-ChildItem -File | ForEach-Object {
        # fix formatting in multiline examples
        $content = Get-Content $_.FullName -Raw
        $newContent = $content -replace '(## EXAMPLE [^`]+?```\r\n[^`\r\n]+?\r\n)(```\r\n\r\n)([^#]+?\r\n)(\r\n)([^#]+)(#)', '$1$3$2$4$5$6'
        if ($newContent -ne $content) {
            Set-Content -Path $_.FullName -Value $newContent -Force
        }
    }
    # Replace each missing element we need for a proper generic module page .md file
    $ModulePageFileContent = Get-Content -raw $ModulePage
    $ModulePageFileContent = $ModulePageFileContent -replace '{{Manually Enter Description Here}}', $script:ModuleDescription
    $Script:FunctionsToExport | ForEach-Object {
        Write-Build DarkGray "             Updating definition for the following function: $($_)"
        $TextToReplace = "{{Manually Enter $($_) Description Here}}"
        $ReplacementText = (Get-Help -Detailed $_).Synopsis
        $ModulePageFileContent = $ModulePageFileContent -replace $TextToReplace, $ReplacementText
    }

    $ModulePageFileContent | Out-File $ModulePage -Force -Encoding:utf8
    Write-Build Gray '     Markdown replacements complete.'

    Write-Build Gray '     Verifying documentation...'
    $MissingDocumentation = Select-String -Path "$($script:ArtifactsPath)\docs\*.md" -Pattern "({{.*}})"
    if ($MissingDocumentation.Count -gt 0) {
        Write-Build Yellow '       The documentation that got generated resulted in missing sections which should be filled out.'
        Write-Build Yellow '       Please review the following sections in your comment based help, fill out missing information and rerun this build:'
        Write-Build Yellow '       (Note: This can happen if the .EXTERNALHELP CBH is defined for a function before running this build.)'
        Write-Build Yellow "             Path of files with issues: $($script:ArtifactsPath)\docs\"
        $MissingDocumentation | Select-Object FileName, Matches | Format-Table -AutoSize
        throw 'Missing documentation. Please review and rebuild.'
    }

    Write-Build Gray '     Markdown generation complete.'
}#CreateMarkdownHelp

# Synopsis: Build the external xml help file from markdown help files with PlatyPS
Add-BuildTask CreateExternalHelp -After CreateMarkdownHelp {
    Write-Build Gray '     Creating external xml help file...'
    $null = New-ExternalHelp "$($script:ArtifactsPath)\docs" -OutputPath "$($script:ArtifactsPath)\en-US\" -Force
    Write-Build Gray '     External xml help file created!'
}#CreateExternalHelp

Add-BuildTask CreateHelpComplete -After CreateExternalHelp {
    Write-Build Green 'CreateHelp Complete!'
}#CreateHelpStart

# Synopsis: Replace comment based help (CBH) with external help in all public functions for this project
Add-BuildTask UpdateCBH -After AssetCopy {
    $ExternalHelp = @"
<#
.EXTERNALHELP $($moduleName)-help.xml
#>
"@

    $CBHPattern = "(?ms)(\<#.*\.SYNOPSIS.*?#>)"
    Get-ChildItem -Path "$($script:ArtifactsPath)\Public\*.ps1" -File | ForEach-Object {
        $FormattedOutFile = $_.FullName
        Write-Output "      Replacing CBH in file: $($FormattedOutFile)"
        $UpdatedFile = (Get-Content  $FormattedOutFile -raw) -replace $CBHPattern, $ExternalHelp
        $UpdatedFile | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
    }
}#UpdateCBH

# Synopsis: Copies module assets to Artifacts folder
Add-BuildTask AssetCopy -Before Build {
    Write-Build Gray '  Copying assets to Artifacts...'
    Copy-Item -Path "$script:ModuleSourcePath\*" -Destination $script:ArtifactsPath -Exclude *.psd1, *.psm1 -Recurse
    Write-Build Gray '  Assets copy complete.'
}#AssetCopy

# Synopsis: Builds the Module to the Artifacts folder
Add-BuildTask Build {
    Write-Build White 'Performing Module Build'

    Write-Build Gray '  Copying manifest file to Artifacts...'
    Copy-Item -Path $script:ModuleManifestFile -Destination $script:ArtifactsPath -Recurse
    Write-Build Gray '  manifest copy complete.'

    Write-Build Gray '  Merging Public and Private functions to one module file...'
    #$private = "$script:ModuleSourcePath\Private"
    $scriptContent = [System.Text.StringBuilder]::new()
    #$powerShellScripts = Get-ChildItem -Path $script:ModuleSourcePath -Filter '*.ps1' -Recurse
    $powerShellScripts = Get-ChildItem -Path $script:ArtifactsPath -Recurse | Where-Object {$_.Name -match '^*.ps1$'}
    foreach ($script in $powerShellScripts) {
        $null = $scriptContent.Append((Get-Content -Path $script.FullName -Raw))
        $null = $scriptContent.AppendLine('')
        $null = $scriptContent.AppendLine('')
    }
    $scriptContent.ToString() | Out-File -FilePath $script:BuildModuleRootFile -Encoding utf8 -Force
    Write-Build Gray '  Module creation complete.'

    Write-Build Gray '  Cleaning up leftover artifacts...'
    #cleanup artifacts that are no longer required
    if (Test-Path "$($script:ArtifactsPath)\Public") {
        Remove-Item "$($script:ArtifactsPath)\Public" -Recurse -Force
    }
    if (Test-Path "$($script:ArtifactsPath)\Private") {
        Remove-Item "$($script:ArtifactsPath)\Private" -Recurse -Force
    }

    Write-Build Gray '  Overwriting docs output...'
    Remove-Item "$($script:ModuleDocsPath)\*.md" -Recurse -Force
    Copy-Item "$($script:ArtifactsPath)\docs\*.md" -Destination $script:ModuleDocsPath -Force
    Move-Item -Path "$($script:ModuleDocsPath)\$($script:ModuleName).md" -Destination "$($script:ModuleDocsPath)\Readme.md"
    Write-Build Gray '  Docs output completed.'

    Write-Build Green 'Build Complete!'
}#Build

#Synopsis: Invokes all Pester Infrastructure Tests in the Tests\Infrastructure folder (if it exists)
Add-BuildTask InfraTest {
    if (Test-Path -Path $script:InfraTestsPath) {

        $invokePesterParams = @{
            Path       = 'Tests\Infrastructure'
            Strict     = $true
            PassThru   = $true
            Verbose    = $false
            EnableExit = $false
        }

        Write-Build White "      Performing Pester Infrastructure Tests in $($invokePesterParams.path)"
        # Publish Test Results as NUnitXml
        $testResults = Invoke-Pester @invokePesterParams

        # This will output a nice json for each failed test (if running in CodeBuild)
        if ($env:CODEBUILD_BUILD_ARN) {
            $testResults.TestResult | ForEach-Object {
                if ($_.Result -ne 'Passed') {
                    ConvertTo-Json -InputObject $_ -Compress
                }
            }
        }

        $numberFails = $testResults.FailedCount
        Assert-Build($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
        Write-Build Green 'Pester Infrastructure Tests Complete!'
    }
}#InfraTest

#Synopsis: Creates an archive of the built Module
Add-BuildTask Archive {
    Write-Build White '  Performing Archive...'

    $archivePath = Join-Path -Path $BuildRoot -ChildPath 'Archive'
    if (Test-Path -Path $archivePath) {
        $null = Remove-Item -Path $archivePath -Recurse -Force
    }

    $null = New-Item -Path $archivePath -ItemType Directory -Force

    $zipFileName = '{0}_{1}_{2}.{3}.zip' -f $script:ModuleName, $script:ModuleVersion, ([DateTime]::UtcNow.ToString("yyyyMMdd")), ([DateTime]::UtcNow.ToString("hhmmss"))
    $zipFile = Join-Path -Path $archivePath -ChildPath $zipFileName

    if ($PSEdition -eq 'Desktop') {
        Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($script:ArtifactsPath, $zipFile)

    Write-Build Green '  Archive Complete!'
}#Archive
