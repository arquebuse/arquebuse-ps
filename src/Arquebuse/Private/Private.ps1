# Function to invoke Arquebuse API and process returned object or errors
function InvokeApi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Object,

        [Parameter()]
        [string]$SubObject = '',

        [Parameter()]
        [string]$ID = '',

        [Parameter()]
        [string]$Version = 'v1',

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [bool]$SkipCertificateCheck = $false
    )

    # As SkipCertificateCheck is not available in PowerShell version before 6
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        # Save Certificate Policy
        $certificatePolicy = [System.Net.ServicePointManager]::CertificatePolicy

        if ($SkipCertificateCheck) {
            if (-not("TrustAllCertsPolicy" -as [type])) {
                Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
            }

            # Replace Certificate Policy
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }

        $SkipCertificateCheckParameter = @{}
    } else {
        $SkipCertificateCheckParameter = @{
            SkipCertificateCheck = $SkipCertificateCheck
        }
    }

    $uri = ($BaseUrl, 'api', $Version, $Object, $SubObject, $ID | Where-Object { $_ }) -join '/'

    $data    = $null
    $message = ''
    $success = $true
    try {
        $data = Invoke-RestMethod -Uri $uri -Method $Method -Headers @{'X-API-Key' = $ApiKey} @SkipCertificateCheckParameter
    } catch {
        $success = $false
        $exception = $_.Exception
        $message = "Error while querying '$uri'. Message: "
        if ($exception.message -like '*SSL*') {
            Write-Verbose $exception.Message
            if ($exception.InnerException) { Write-Verbose $exception.InnerException.Message }
            $message += "Bad SSL certificate - Please verify your SSL configuration or use -SkipCertificateCheck parameter"
        } else {
            if ($exception.Response) {
                $statusCode = [Int32]$exception.Response.StatusCode
                switch ($statusCode) {
                    401 {
                        $message += "Unauthorized - Please verify your API-Key"
                    }
                    404 {
                        $message = ''
                        $success = $true
                    }
                    default {
                        $message += "Status Code: $statuscode - $($exception.Message)"
                    }
                }
            } else {
                if ($exception.InnerException) {
                    $message += $exception.InnerException.Message
                } else {
                    $message += $exception.Message
                }
            }
        }
    } finally {
        # Restore previously saved Certificate Policy
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [System.Net.ServicePointManager]::CertificatePolicy = $certificatePolicy
        }
    }

    return [PSCustomObject]@{
        Success = $success
        Data    = $data
        Message = $message
    }
}

# Function to get API version object from remote API
function GetApiVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$CommonApiParameters
    )

    $result = (InvokeApi -Object 'system' -SubObject 'info' @CommonApiParameters)

    if ($result.Success) {
        return $result.Data
    } else {
        Throw $result.message
    }
}

# Function to list inbound emails
function GetInbound {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$CommonApiParameters
    )

    $result = (InvokeApi -Object 'inbound' @CommonApiParameters)

    if ($result.Success) {
        return $result.Data
    } else {
        Throw $result.message
    }
}

# Function to list outbound emails
function GetOutbound {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$CommonApiParameters
    )

    $result = (InvokeApi -Object 'outbound' @CommonApiParameters)

    if ($result.Success) {
        return $result.Data
    } else {
        Throw $result.message
    }
}

# Function to get HOME path (usefull in unit tests)
function GetHome { return $HOME }

# Function to get common API parameters from command line arguments or from configuration
function GetCommonApiParameters {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ConfigPath,

        [Parameter()]
        [string]$BaseUrl,

        [Parameter()]
        [string]$ApiKey,

        [Parameter()]
        [bool]$SkipCertificateCheck = $false
    )

    $parameters = @{
        BaseUrl              = 'https://localhost'
        SkipCertificateCheck = $false
        ApiKey               = ''
    }

    if ($ConfigPath) {
        $configPathCandidate = @( $ConfigPath )
    } else {
        $configPathCandidate = @(
            $(Join-Path -Path $(GetHome) -ChildPath '.arquebuse.psd1')
            $(Join-Path -Path $(GetHome) -ChildPath '.arquebuse.json')
        )
    }

    $config = $null
    foreach ($path in $configPathCandidate) {
        if (Test-Path -Path $path -PathType Leaf -ErrorAction SilentlyContinue) {
            $extension = Split-Path -Path $path -Extension
            switch ($extension) {
                '.psd1' {
                    try {
                        $config = Import-PowerShellDataFile -Path $path | ConvertTo-Json -Depth 99 | ConvertFrom-Json
                        Write-Verbose "Successfully loaded config file '$path'"
                    } catch {
                        Write-Warning "Failed to load config file '$path'. Message: $($_.Exception.Message)"
                    }
                }
                '.json' {
                    try {
                        $config = Get-Content -Path $path -Raw | ConvertFrom-Json
                        Write-Verbose "Successfully loaded config file '$path'"
                    } catch {
                        Write-Warning "Failed to load config file '$path'. Message: $($_.Exception.Message)"
                    }
                }
                default {
                    Write-Warning "Cannot load config file '$path'. Supported extensions are JSON and PSD1"
                }
            }
        }

        if ($config) {
            break
        }
    }

    if ($config -and (Get-Member -InputObject $config -Name 'DefaultServer')) {
        $defaultServer = $config.DefaultServer
        if (Get-Member -InputObject $defaultServer -Name 'BaseUrl') {
            $parameters.BaseUrl = $defaultServer.BaseUrl
        }

        if (Get-Member -InputObject $defaultServer -Name 'ApiKey') {
            $parameters.ApiKey = $defaultServer.ApiKey
        }

        if (Get-Member -InputObject $defaultServer -Name 'SkipCertificateCheck') {
            $parameters.SkipCertificateCheck = $defaultServer.SkipCertificateCheck
        }
    }

    if ($BaseUrl) {
        $parameters.BaseUrl = $BaseUrl
    }

    if ($ApiKey) {
        $parameters.ApiKey = $ApiKey
    }

    if ($SkipCertificateCheck) {
        $parameters.SkipCertificateCheck = $SkipCertificateCheck
    }

    return $parameters

}

# Function to convert a PSCustomObject into an ArquebuseEmail object
function ToEmailObject {
    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )

    Process {
        if (Get-Member -InputObject $InputObject -Name 'client') {
            $client = $InputObject.client
            if ($client -match "^(?<client>[^:]+):(?<port>[0-9]+)$") {
                $client = $Matches['client']
                $clientPort = [int]$Matches['port']
            } else {
                $clientPort = 0
            }
        } else {
            $client     = ""
            $clientPort = 0
        }

        if (Get-Member -InputObject $InputObject -Name 'from') {
            $from = $InputObject.from
        } else {
            $from = ""
        }

        if (Get-Member -InputObject $InputObject -Name 'id') {
            $id = $InputObject.id
        } else {
            $id = ""
        }

        if (Get-Member -InputObject $InputObject -Name 'subject') {
            $subject = $InputObject.subject
        } else {
            $subject = ""
        }

        if (Get-Member -InputObject $InputObject -Name 'timestamp') {
            $date = Get-Date -Date $InputObject.timestamp
        } else {
            $date = Get-Date
        }

        if (Get-Member -InputObject $InputObject -Name 'to') {
            $to = $InputObject.to
        } else {
            $to = ""
        }

        if (Get-Member -InputObject $InputObject -Name 'status') {
            $status = $InputObject.status
        } else {
            $status = "RECEIVED"
        }

        $email = [PSCustomObject]@{
            Date       = $date
            Status     = $status
            ID         = $id
            Client     = $client
            ClientPort = $clientPort
            From       = $from
            To         = $to
            Subject    = $subject
        }

        $email.PSObject.TypeNames.Insert(0, 'ArquebuseEmail')

        return $email
    }
}