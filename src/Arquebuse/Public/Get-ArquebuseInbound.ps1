<#
.SYNOPSIS
    Get Arquebuse server inbound content
.DESCRIPTION
    Get email list from remote Arquebuse server's Inbound queue
.EXAMPLE
    PS> Get-ArquebuseInbound

    Get inbound content from the default Arquebuse server listed in default Arquebuse config file (.arquebuse.json or .arquebuse.psd1 in home folder)
.EXAMPLE
    PS> Get-ArquebuseInbound -Config ./arquebuse-config.json

    Get inbound content from the default Arquebuse server listed in file ./arquebuse-config.json
.EXAMPLE
    PS> Get-ArquebuseInbound -BaseUrl https://localhost -ApiKey AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE -SkipCertificateCheck

    Get inbound content from a local Arquebuse server with the specified API key and without checking the server's certificate
.PARAMETER Config
    Path to an Arquebuse client config file
.PARAMETER BaseUrl
    Base URL of the Arquebuse Server (starts with https://)
.PARAMETER ApiKey
    API Key for authentication to the Arquebuse server
.PARAMETER SkipCertificateCheck
    If the Arquebuse server doesn't have a valid SSL certificate - Not recommended !
.OUTPUTS
    List of indound's emails
#>
function Get-ArquebuseInbound {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'Path to an Arquebuse client config file')]
        [string]$Config,

        [Parameter(HelpMessage = 'Base URL of the Arquebuse Server (starts with https://)')]
        [string]$BaseUrl,

        [Parameter(HelpMessage = 'API Key for authentication to the Arquebuse server')]
        [string]$ApiKey,

        [Parameter(HelpMessage = "If the Arquebuse server doesn't have a valid SSL certificate - Not recommended !")]
        [switch]$SkipCertificateCheck
    )

    $commonApiParameters = GetCommonApiParameters -ApiKey $ApiKey -BaseUrl $BaseUrl -ConfigPath $Config -SkipCertificateCheck $SkipCertificateCheck.IsPresent

    return (GetInbound -CommonApiParameters $commonApiParameters | ToEmailObject )
}#Get-ArquebuseInbound