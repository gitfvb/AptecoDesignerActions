
#-----------------------------------------------
# SOAP AUTHENTICATION
#-----------------------------------------------

# $securePassword = ConvertTo-SecureString (Get-SecureToPlaintext $settings.soap.password) -AsPlainText -Force
# $cred = [System.Management.Automation.PSCredential]::new($settings.soap.username,$securePassword)


#-----------------------------------------------
# REST AUTHENTICATION
#-----------------------------------------------
<#
$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}
#>