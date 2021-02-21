
################################################
#
# START
#
################################################

#-----------------------------------------------
# LOAD SCRIPTPATH
#-----------------------------------------------

if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


#-----------------------------------------------
# LOAD MORE FUNCTIONS
#-----------------------------------------------

$functionsSubfolder = ".\functions"

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\emarsys.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR UPLOAD FOLDER
#-----------------------------------------------

# Default file
$uploadDefault = "$( $scriptPath )\uploads"

# Ask for another path
$upload = Read-Host -Prompt "Where do you want the files to be uploaded? Just press Enter for this default [$( $uploadDefault )]"

# If prompt is empty, just use default path
if ( $upload -eq "" -or $null -eq $upload) {
    $upload = $uploadDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $upload -IsValid ) {
    Write-Host "Upload folder '$( $upload )' is valid"
} else {
    Write-Host "Upload folder '$( $upload )' contains invalid characters"
}



#-----------------------------------------------
# ASK FOR DOWNLOAD FOLDER
#-----------------------------------------------

# Default file
$downloadDefault = "$( $scriptPath )\downloads"

# Ask for another path
$download = Read-Host -Prompt "Where do you want the files to be downloaded? Just press Enter for this default [$( $downloadDefault )]"

# If prompt is empty, just use default path
if ( $download -eq "" -or $null -eq $download) {
    $download = $downloadDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $upload -IsValid ) {
    Write-Host "Upload folder '$( $download )' is valid"
} else {
    Write-Host "Upload folder '$( $download )' contains invalid characters"
}



################################################
#
# SETUP SETTINGS
#
################################################

#-----------------------------------------------
# SECURITY / LOGIN
#-----------------------------------------------

$keyfile = "$( $scriptPath )\aes.key"
$user = Read-Host -Prompt "Please enter the username for emarsys"
$secret = Read-Host -AsSecureString "Please enter the secret for emarsys"
$secretEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password)

$loginSettings = @{
    username = $user
    secret = $secretEncrypted
}

 
#-----------------------------------------------
# MAILINGS SETTINGS
#-----------------------------------------------

$mailingsSettings = @{
    "languageCode" = "de"   # languagecode for email templates in elettershop
}


#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email"                # Email|Sms
    "FromAddress"="info@apteco.de"  # 
    "FromName"="Apteco"             # 
    "ReplyTo"="info@apteco.de"      # 
    "Subject"="Test-Subject"        # 
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    folder = $upload
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$downloadSettings = @{
    folder = $download
}



#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?
# TODO [ ] Documentation of all these parameters and the ones above

$settings = @{

    # General
    base            = "https://trunk-int.s.emarsys.com/api/v2/" #"https://api.emarsys.net/api/v2/"  # Default url
    changeTLS       = $true                             # should tls be changed on the system?
    nameConcatChar  = " / "                             # character to concat mailing/campaign id with mailing/campaign name
    logfile         = $logfile                          # path and name of log file
    providername    = "emarsys"                         # identifier for this custom integration, this is used for the response allocation

    # Session 
    aesFile         = $keyFile
    
    # Detail settings
    login = $loginSettings
    download = $downloadSettings
    #mailings = $mailingsSettings
    #preview = $previewSettings
    upload = $uploadSettings

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8


################################################
#
# CREATE FOLDERS IF NEEDED
#
################################################

if ( !(Test-Path -Path $settings.upload.folder) ) {
    Write-Log -message "Upload $( $settings.upload.folder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $settings.upload.folder )" -ItemType Directory
}


if ( !(Test-Path -Path $settings.download.folder) ) {
    Write-Log -message "Download $( $settings.download.folder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $settings.download.folder )" -ItemType Directory
}
