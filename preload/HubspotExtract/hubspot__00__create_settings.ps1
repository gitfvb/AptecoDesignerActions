
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"


################################################
#
# FUNCTIONS
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


################################################
#
# SETUP SETTINGS
#
################################################


#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$keyFile = "$( $scriptPath )\aes.key"
$token = Read-Host -AsSecureString "Please enter the current hapikey"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password) 

$loginSettings = [PSCustomObject]@{
    "hapikey" = $tokenEncrypted 
}


#-----------------------------------------------
# MAIL SETTINGS
#-----------------------------------------------

# typically something like contacts and companies
$objectTypesToLoad = @(
    "contacts"
    "companies"
)


#-----------------------------------------------
# MAIL SETTINGS
#-----------------------------------------------

$mailPass = Read-Host -AsSecureString "Please enter the current smpt password"
$mailPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password) 

# Settings for smtp mails
$mailSettings = [PSCustomObject]@{
    password = $mailPassEncrypted
}



#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?
# TODO [ ] Documentation of all these parameters and the ones above

$settings = [PSCustomObject]@{

    # General
    base = "https://api.hubapi.com/"
    logfile="$( $scriptPath )\hubspot.log"               # path and name of log file, please make sure the path exists
    changeTLS = $true                                   # should tls be changed on the system?
    providername = "HBSPT"                                # identifier for this custom integration, this is used for the response allocation   

    # API settings
    loadArchivedRecords = $true
    pageLimitGet = 100 # Max amount of records to download with one API call

    # hubspot settings
    objectTypesToLoad = $objectTypesToLoad

    # local directories
    exportDir = "$( $scriptPath )\extract"
    backupDir = "$( $scriptPath )\backup"

    # sqlite settings
    sqliteDb = "$( $scriptPath )\data\hubspot.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    sqliteImportFilter = @("*.csv";"*.txt";"*.tab")
    backupSqlite = $true # $true|$false if you wish to create backups of the sqlite database

    # build now file settings
    createBuildNow = $false # $true|$false if you want to create an empty file for "build.now"
    buildNowFile = "$( $scriptPath )\build.now" # Path to the build now file
 
    # Session 
    aesFile = $keyFile
    sessionFile = "$( $scriptPath )\lastsession.json"
    saveHapiKeyAsFile = $true
    hapiKeyFile = "$( $scriptPath )\hapi.key"

    # Detail settings
    login = $loginSettings
    mail = $mailSettings

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8


################################################
#
# SAVE HAPIKEY AS FILE
#
################################################

if ( $settings.saveHapiKeyAsFile ) {

    $Env:HAPIKEY = Get-SecureToPlaintext -String $tokenEncrypted
    . ".\hubspot__01__save_api_key.ps1" "$( $scriptPath )"

}

