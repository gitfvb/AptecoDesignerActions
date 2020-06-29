################################################
#
# NOTES
#
################################################

<#

#>


################################################
#
# FUNCTIONS
#
################################################



Function Get-GoToSession {


    $sessionPath = "$( $settings.session.file )"
    $createNewSession = $true

    # if file exists -> read it and check ttl
    if ( (Test-Path -Path $sessionPath) -eq $true ) {

        $sessionContent = Get-Content -Encoding UTF8 -Path $sessionPath -Raw | ConvertFrom-Json
        
        $expire = [datetime]::ParseExact($sessionContent.expire,"yyyyMMddHHmmss",[CultureInfo]::InvariantCulture)

        if ( $expire -gt [datetime]::Now ) {

            $createNewSession = $false
            $Script:sessionId = $sessionContent.sessionId
            $Script:account = $sessionContent.account
            $Script:organizer = $sessionContent.organizer  
            
        } else {

            $refreshToken = $sessionContent.refreshToken

        }

    } else {

        $refreshToken = $settings.session.initialRefreshToken
        
    }
    
    # file does not exist or date is not valid -> create session
    if ( $createNewSession -eq $true ) {
        
        # Create body for new token
        $body = @{
            "grant_type" = "refresh_token"
            "refresh_token" = $refreshToken
        }

        # Create basic auth for obtaining token
        [string]$userName = $settings.session.clientId
        [string]$userPassword = Get-SecureToPlaintext -String $settings.session.clientSecret
        $credPair = "$($username):$($userPassword)"
        $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
        $headers = @{ Authorization = "Basic $encodedCredentials" }
        
        # Get new access and refresh token
        $newSession = Invoke-RestMethod -Method Post -Uri "$( $settings.base )oauth/v2/token" -ContentType "application/x-www-form-urlencoded" -Body $body -Headers $headers -Verbose #-Credential $cred

        # Calculate expiration date
        $expire = [datetime]::now.AddSeconds($newSession.expires_in).ToString("yyyyMMddHHmmss")

        # Encrypt token, if needed
        if ( $settings.session.encryptToken ) {
            $Script:sessionId = Get-PlaintextToSecure -String $newSession.access_token
        } else {
            $Script:sessionId = $newSession.access_token
        }

        $Script:account = $newSession.account_key
        $Script:organizer = $newSession.organizer_key
        $Script:session = $newSession

        $session = @{
            sessionId=$Script:sessionId
            expire=$expire
            refreshToken=$newSession.refresh_token
            account = $newSession.account_key
            organizer = $newSession.organizer_key
        }
        $session | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $sessionPath
    #>
    
    }

    
    
}



