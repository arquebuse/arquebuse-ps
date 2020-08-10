#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$PathToPrivateFunction = [System.IO.Path]::Combine('..', '..', $ModuleName, 'Private', 'Private.ps1')
$PathToPsd1ConfigFile  = [System.IO.Path]::Combine('..', 'Resources', 'config.psd1')
$PathToFakePsd1File  = [System.IO.Path]::Combine('..', 'Resources', 'fake.psd1')
$PathToFakeJsonFile  = [System.IO.Path]::Combine('..', 'Resources', 'fake.json')
$PathToYamlConfigFile  = [System.IO.Path]::Combine('..', 'Resources', 'config.yaml')
$PathToHome  = [System.IO.Path]::Combine('..', 'Resources', 'Home')
#-------------------------------------------------------------------------
. $PathToPrivateFunction
#-------------------------------------------------------------------------
$WarningPreference = "SilentlyContinue"
#-------------------------------------------------------------------------

function Assert-HashtableEquality($test, $expected) {
    $test.Keys | Should -HaveCount $expected.Keys.Count
    $test.Keys | ForEach-Object {$test[$_] | Should -Be $expected[$_]}
}

Describe 'Arquebuse Private Function Tests' -Tag Unit {
    Context 'GetHome' {
        It 'Returns the HOME folder' {
            GetHome | Should -Be $HOME
        }
    }

    Context 'GetCommonApiParameters' {
        Mock GetHome {return 'nowhere'}

        It 'Returns the default values' {
            $test = GetCommonApiParameters
            $test.BaseUrl | Should -Be 'https://localhost'
            $test.SkipCertificateCheck | Should -Be $false
            $test.ApiKey | Should -Be ''
        }

        It 'Returns the default values when a bad JSON config file is provided' {
            $test = GetCommonApiParameters -ConfigPath $PathToFakeJsonFile
            $test.BaseUrl | Should -Be 'https://localhost'
            $test.SkipCertificateCheck | Should -Be $false
            $test.ApiKey | Should -Be ''
        }

        It 'Returns the default values when a bad PSD1 config file is provided' {
            $test = GetCommonApiParameters -ConfigPath $PathToFakePsd1File
            $test.BaseUrl | Should -Be 'https://localhost'
            $test.SkipCertificateCheck | Should -Be $false
            $test.ApiKey | Should -Be ''
        }

        It 'Returns the default values when an unsupported config file is provided' {
            $test = GetCommonApiParameters -ConfigPath $PathToYamlConfigFile
            $test.BaseUrl | Should -Be 'https://localhost'
            $test.SkipCertificateCheck | Should -Be $false
            $test.ApiKey | Should -Be ''
        }

        It 'Returns values from a specified PSD1 config file' {
            $test = GetCommonApiParameters -ConfigPath $PathToPsd1ConfigFile
            $test.BaseUrl | Should -Be 'fake-url'
            $test.SkipCertificateCheck | Should -Be $true
            $test.ApiKey | Should -Be 'fake-api-key'
        }

        It 'Returns values from a specified PSD1 config file + overrided ones' {
            $test = GetCommonApiParameters -ConfigPath $PathToPsd1ConfigFile -BaseUrl 'my-url'
            $test.BaseUrl | Should -Be 'my-url'
            $test.SkipCertificateCheck | Should -Be $true
            $test.ApiKey | Should -Be 'fake-api-key'
        }

        Mock GetHome {return $PathToHome}

        It 'Returns values from default json config file' {
            $test = GetCommonApiParameters
            $test.BaseUrl | Should -Be 'another-fake-url'
            $test.SkipCertificateCheck | Should -Be $false
            $test.ApiKey | Should -Be 'another-fake-api-key'
        }

        It 'Returns values from default json config file' {
            $test = GetCommonApiParameters -APIKey 'my-api-key' -SkipCertificateCheck $true
            $test.BaseUrl | Should -Be 'another-fake-url'
            $test.SkipCertificateCheck | Should -Be $true
            $test.ApiKey | Should -Be 'my-api-key'
        }

    }

    Context 'InvokeApi' {
        Mock Invoke-RestMethod {return 'test'}

        $ApiParameters = @{
            BaseUrl = 'fake-url'
            ApiKey  = 'fake-api-key'
            Object  = 'test'
        }

        It 'Returns the requested object' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $true
            $result.Message | Should -Be ''
            $result.Data    | Should -Be 'test'
        }

        Mock Invoke-RestMethod {
            $httpResponseMessage = [System.Net.Http.HttpResponseMessage]::new(404)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("404 page not found", $httpResponseMessage)
        }

        It 'Returns null when API returns a 404' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $true
            $result.Message | Should -Be ''
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            $innerException = [System.SystemException]::new("The remote certificate is invalid according to the validation procedure.")
            throw [System.Net.Http.HttpRequestException]::new("The SSL connection could not be established, see inner exception.", $innerException)
        }

        It 'Reports bad SSL certificates' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*-SkipCertificateCheck*'
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            $httpResponseMessage = [System.Net.Http.HttpResponseMessage]::new(401)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Not Authorized", $httpResponseMessage)
        }

        It 'Advices to check API-Key' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*API-Key*'
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            $httpResponseMessage = [System.Net.Http.HttpResponseMessage]::new(500)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Internal error", $httpResponseMessage)
        }

        It 'Reports unknown status codes' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*Status Code: 500*'
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            throw "Find Me"
        }

        It 'Reports unknown exceptions' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*Find Me*'
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Find Me", $null)
        }

        It 'Reports unknown HTTP exceptions' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*Find Me*'
            $result.Data    | Should -Be $null
        }

        Mock Invoke-RestMethod {
            $innerException = [System.SystemException]::new("Find Me")
            throw [System.Net.Http.HttpRequestException]::new("Unknown error", $innerException)
        }

        It 'Reports unknown HTTP inner exceptions' {
            $result = InvokeApi @ApiParameters
            $result.Success | Should -Be $false
            $result.Message | Should -BeLike '*Find Me*'
            $result.Data    | Should -Be $null
        }
    }

    Context 'GetApiVersion' {
        Mock Invoke-RestMethod {return 'version'}

        It 'Returns the remote API version' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            GetApiVersion -CommonApiParameters $commonApiParameters | Should -Be 'version'
        }

        Mock Invoke-RestMethod {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
        }

        It 'Throws when API is not available' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            { GetApiVersion -CommonApiParameters $commonApiParameters } | Should -Throw
        }
    }

    Context 'GetInbound' {
        Mock Invoke-RestMethod {return [PSCustomObject]@{
            id        = "1fuzRupHO5euYJCaKOFovsfY3Ck"
            timestamp = "2020-08-10T18:06:00.911185495Z"
            client    = "127.0.0.1:33472"
            from      = "someone@arquebuse.org"
            to        = "someone.else@arquebuse.org"
            subject   = "Hello from Arquebuse UI !!!"
        }}

        It 'Returns the list of inbound emails' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            $result = GetInbound -CommonApiParameters $commonApiParameters
            $result.id | Should -Be "1fuzRupHO5euYJCaKOFovsfY3Ck"
            $result.timestamp | Should -Be "2020-08-10T18:06:00.911185495Z"
            $result.client | Should -Be "127.0.0.1:33472"
            $result.from | Should -Be "someone@arquebuse.org"
            $result.to | Should -Be "someone.else@arquebuse.org"
            $result.subject | Should -Be "Hello from Arquebuse UI !!!"
        }

        Mock Invoke-RestMethod {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
        }

        It 'Throws when API is not available' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            { GetInbound -CommonApiParameters $commonApiParameters } | Should -Throw
        }
    }

    Context 'GetOutbound' {
        Mock Invoke-RestMethod {return [PSCustomObject]@{
            id        = "1fuzRupHO5euYJCaKOFovsfY3Ck"
            timestamp = "2020-08-10T18:06:00.911185495Z"
            client    = "127.0.0.1:33472"
            from      = "someone@arquebuse.org"
            to        = "someone.else@arquebuse.org"
            subject   = "Hello from Arquebuse UI !!!"
        }}

        It 'Returns the list of outbound emails' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            $result = GetOutbound -CommonApiParameters $commonApiParameters
            $result.id | Should -Be "1fuzRupHO5euYJCaKOFovsfY3Ck"
            $result.timestamp | Should -Be "2020-08-10T18:06:00.911185495Z"
            $result.client | Should -Be "127.0.0.1:33472"
            $result.from | Should -Be "someone@arquebuse.org"
            $result.to | Should -Be "someone.else@arquebuse.org"
            $result.subject | Should -Be "Hello from Arquebuse UI !!!"
        }

        Mock Invoke-RestMethod {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("Unknow error", $null)
        }

        It 'Throws when API is not available' {
            $commonApiParameters = @{
                BaseUrl              = 'fake-url'
                ApiKey               = 'fake-api-key'
            }
            { GetOutbound -CommonApiParameters $commonApiParameters } | Should -Throw
        }
    }

    Context 'ToEmailObject' {
        It 'Converts a valid email result into an ArquebuseEmail object' {
            $object = [PSCustomObject]@{
                id        = "1fuzRupHO5euYJCaKOFovsfY3Ck"
                timestamp = "2020-08-10T18:06:00.911185495Z"
                client    = "127.0.0.1:33472"
                from      = "someone@arquebuse.org"
                to        = "someone.else@arquebuse.org"
                subject   = "Hello from Arquebuse UI !!!"
                status    = "Sent"
            }
            $result = ToEmailObject -InputObject $object
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
            $result.Status      | Should -Be "Sent"
        }

        It 'Returns default values for absent object values' {
            $object = [PSCustomObject]@{}
            $result = ToEmailObject -InputObject $object
            $result.Date.Year   | Should -Be $(Get-Date).Year
            $result.Date.Month  | Should -Be $(Get-Date).Month
            $result.Date.Day    | Should -Be $(Get-Date).Day
            $result.Date.Hour   | Should -Be $(Get-Date).Hour
            $result.Date.Minute | Should -Be $(Get-Date).Minute
            $result.Date.Second | Should -Be $(Get-Date).Second
            $result.ID          | Should -Be ""
            $result.Client      | Should -Be ""
            $result.ClientPort  | Should -Be 0
            $result.From        | Should -Be ""
            $result.To          | Should -Be ""
            $result.Subject     | Should -Be ""
            $result.Status      | Should -Be "RECEIVED"
        }

        It 'Returns default values for incorrect object values' {
            $object = [PSCustomObject]@{
                client    = "error"
            }
            $result = ToEmailObject -InputObject $object
            $result.Client      | Should -Be "error"
            $result.ClientPort  | Should -Be 0
        }
    }
}