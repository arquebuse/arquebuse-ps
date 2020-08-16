---
external help file: Arquebuse-help.xml
Module Name: Arquebuse
online version:
schema: 2.0.0
---

# Get-ArquebuseOutbound

## SYNOPSIS
Get Arquebuse server outbound content

## SYNTAX

```
Get-ArquebuseOutbound [[-Config] <String>] [[-BaseUrl] <String>] [[-ApiKey] <String>] [-SkipCertificateCheck]
 [<CommonParameters>]
```

## DESCRIPTION
Get email list from remote Arquebuse server's Outbound queue

## EXAMPLES

### EXAMPLE 1
```
Get-ArquebuseOutbound
```

Get outbound content from the default Arquebuse server listed in default Arquebuse config file (.arquebuse.json or .arquebuse.psd1 in home folder)

### EXAMPLE 2
```
Get-ArquebuseOutbound -Config ./arquebuse-config.json
```

Get outbound content from the default Arquebuse server listed in file ./arquebuse-config.json

### EXAMPLE 3
```
Get-ArquebuseOutbound -BaseUrl https://localhost -ApiKey AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE -SkipCertificateCheck
```

Get outbound content from a local Arquebuse server with the specified API key and without checking the server's certificate

## PARAMETERS

### -Config
Path to an Arquebuse client config file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BaseUrl
Base URL of the Arquebuse Server (starts with https://)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
API Key for authentication to the Arquebuse server

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCertificateCheck
If the Arquebuse server doesn't have a valid SSL certificate - Not recommended !

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### List of indound's emails
## NOTES

## RELATED LINKS
