################################################
#
# INPUT
#
################################################

Param(
     $scriptPath
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false




################################################
#
# NOTES
#
################################################



################################################
#
# SCRIPT ROOT
#
################################################

#if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
#} else {
#    $scriptPath = "$( $params.scriptPath )" 
#}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "hubspot_apikey"
$timestamp = [datetime]::Now

# Load last session
#$lastSession = Get-Content -Path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# TODO  [ ] unify settings in json file
$settings = @{

    # Security settings
    aesFile = "$( $scriptPath )\aes.key"

    logfile = "$( $scriptPath )\hubspot_extract.log"

}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
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
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################


# Create general settings
$keyfilename = $settings.aesFile
$hapikeyFilename = ".\hapi.key" # [ ] TODO Replace with $settings.hapikeyFile 
$keyFile = $settings.aesFile # [ ] TODO Check if this is needed


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# SAVE TOKEN ENCRYPTED IN A SEPARATE FILE
#
################################################

Get-PlaintextToSecure -String $Env:HAPIKEY | Set-Content -Path $hapikeyFilename -Encoding UTF8



