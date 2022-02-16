# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Setup default credentials for proxy communication per default
$proxyUrl = $null
if ( $settings.proxy.proxyUrl ) {
    $proxyUrl = $settings.proxy.proxyUrl
    $useDefaultCredentials = $true

    if ( $settings.proxy.proxyUseDefaultCredentials ) {
        $proxyUseDefaultCredentials = $true
        [System.Net.WebRequest]::DefaultWebProxy.Credentials=[System.Net.CredentialCache]::DefaultCredentials
    } else {
        $proxyUseDefaultCredentials = $false
        $proxyCredentials = New-Object PSCredential $settings.proxy.credentials.username,( Get-SecureToPlaintext -String $settings.proxy.credentials.password )
    }

}

function Check-Proxy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][Hashtable]$invokeParams
    )
    
    begin {
        
    }
    
    process {
        if ( $script:proxyUrl ) {
            $invokeParams.Add("Proxy", $script:proxyUrl)
            $invokeParams.Add("UseDefaultCredentials", $script:useDefaultCredentials)
            if ( $script:proxyUseDefaultCredentials ) {
                $invokeParams.Add("ProxyUseDefaultCredentials", $true)
            } else {
                $invokeParams.Add("ProxyCredential", $script:proxyCredentials)         
            }
        }
    }
    
    end {
        
    }
}

<#
# Add proxy settings
if ( $proxyUrl ) {
    $paramsPost.Add("Proxy", $proxyUrl)
    $paramsPost.Add("UseDefaultCredentials", $useDefaultCredentials)
    if ( $proxyUseDefaultCredentials ) {
        $paramsPost.Add("ProxyUseDefaultCredentials", $true)
    } else {
        $paramsPost.Add("ProxyCredential", $proxyCredentials)         
    }
}
#>











<#
# The following can be added to api calls

if ( $proxyUrl ) {
    $paramsPost.Add("UseDefaultCredentials", $useDefaultCredentials)
    $paramsPost.Add("Proxy", $proxyUrl)
}

#if ( $settings.useDefaultCredentials ) {
#    $paramsPost.Add("UseDefaultCredentials", $true)
#}

$paramsPost.Add("ProxyCredential", pscredential)

if ( $settings.ProxyUseDefaultCredentials ) {
    $paramsPost.Add("ProxyUseDefaultCredentials", $true)
}


#>