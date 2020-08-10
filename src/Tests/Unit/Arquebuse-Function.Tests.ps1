#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'Arquebuse'
$PathToManifest = [System.IO.Path]::Combine('..', '..', $ModuleName, "$ModuleName.psd1")
#-------------------------------------------------------------------------
if (Get-Module -Name $ModuleName -ErrorAction 'SilentlyContinue') {
    #if the module is already in memory, remove it
    Remove-Module -Name $ModuleName -Force
}
Import-Module $PathToManifest -Force
#-------------------------------------------------------------------------
$WarningPreference = "SilentlyContinue"
#-------------------------------------------------------------------------
#Import-Module $moduleNamePath -Force

InModuleScope 'Arquebuse' {
    #-------------------------------------------------------------------------
    $WarningPreference = "SilentlyContinue"
    #-------------------------------------------------------------------------

    Describe 'Arquebuse Public Function Tests' -Tag Unit {
        Context 'Get-ArquebuseVersion' {
            Mock Invoke-RestMethod {return 'version'}

            It 'Returns the remote API version' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }
                Get-ArquebuseVersion @commandParameters | Should -Be 'version'
            }

            Mock Invoke-RestMethod {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
            }

            It 'Throws when API is not available' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }
                { GetApiVersion @commandParameters } | Should -Throw
            }
        }

        Context 'Get-ArquebuseInbound' {
            Mock Invoke-RestMethod {return [PSCustomObject]@{
                id        = "1fuzRupHO5euYJCaKOFovsfY3Ck"
                timestamp = "2020-08-10T18:06:00.911185495Z"
                client    = "127.0.0.1:33472"
                from      = "someone@arquebuse.org"
                to        = "someone.else@arquebuse.org"
                subject   = "Hello from Arquebuse UI !!!"
            }}

            It 'Returns the list of inbound emails' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }

                $result = Get-ArquebuseInbound @commandParameters
                $result.Date.Year   | Should -Be 2020
                $result.Date.Month  | Should -Be 8
                $result.Date.Day    | Should -Be 10
                $result.Date.Hour   | Should -Be 20
                $result.Date.Minute | Should -Be 6
                $result.Date.Second | Should -Be 0
                $result.ID          | Should -Be "1fuzRupHO5euYJCaKOFovsfY3Ck"
                $result.Client      | Should -Be "127.0.0.1"
                $result.ClientPort  | Should -Be 33472
                $result.From        | Should -Be "someone@arquebuse.org"
                $result.To          | Should -Be "someone.else@arquebuse.org"
                $result.Subject     | Should -Be "Hello from Arquebuse UI !!!"
                $result.Status      | Should -Be "RECEIVED"
            }

            Mock Invoke-RestMethod {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
            }

            It 'Throws when API is not available' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }

                { Get-ArquebuseInbound @commandParameters } | Should -Throw
            }
        }

        Context 'Get-ArquebuseOutbound' {
            Mock Invoke-RestMethod {return [PSCustomObject]@{
                id        = "1fuzRupHO5euYJCaKOFovsfY3Ck"
                timestamp = "2020-08-10T18:06:00.911185495Z"
                client    = "127.0.0.1:33472"
                from      = "someone@arquebuse.org"
                to        = "someone.else@arquebuse.org"
                subject   = "Hello from Arquebuse UI !!!"
                status    = "Failed"
            }}

            It 'Returns the list of outbound emails' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }

                $result = Get-ArquebuseOutbound @commandParameters
                $result.Date.Year   | Should -Be 2020
                $result.Date.Month  | Should -Be 8
                $result.Date.Day    | Should -Be 10
                $result.Date.Hour   | Should -Be 20
                $result.Date.Minute | Should -Be 6
                $result.Date.Second | Should -Be 0
                $result.ID          | Should -Be "1fuzRupHO5euYJCaKOFovsfY3Ck"
                $result.Client      | Should -Be "127.0.0.1"
                $result.ClientPort  | Should -Be 33472
                $result.From        | Should -Be "someone@arquebuse.org"
                $result.To          | Should -Be "someone.else@arquebuse.org"
                $result.Subject     | Should -Be "Hello from Arquebuse UI !!!"
                $result.Status      | Should -Be "Failed"
            }

            Mock Invoke-RestMethod {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
            }

            It 'Throws when API is not available' {
                $commandParameters = @{
                    BaseUrl              = 'fake-url'
                    ApiKey               = 'fake-api-key'
                    SkipCertificateCheck = $false
                }

                { Get-ArquebuseOutbound @commandParameters } | Should -Throw
            }
        }
    }
}
