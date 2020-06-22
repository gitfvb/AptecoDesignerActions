################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# NOTES
#
################################################



<#

Links
https://developers.hubspot.com/docs/methods/contacts/v2/get_contacts_properties
https://developers.hubspot.com/docs/api/crm/contacts


possible hierarchy

contacts (lookup for global attributes; dynamic datasource?)
    -> groups
    -> mailings
        -> events (mailing dependent like open, click, bounce etc)
        -> attributes (local; dynamic datasource?)
        -> groups
    -> events (non mailing dependent)
    -> orders
    -> tags

#>



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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "cleverreach_extract"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# TODO  [ ] unify settings in json file
$settings = @{

    # Security settings
    aesFile = "$( $scriptPath )\aes.key"

    # Create a secure string like
    # Get-PlaintextToSecure -String "token" -keyFile "$( $scriptPath )\aes.key"
    # And get it plaintext back by
    # Get-SecureToPlaintext -String $settings.token 
    token = "76492d1116743f0423413b16050a5345MgB8AHgAdwA2AEUAVwBIAHMAVwBKAFUAbAB1AEkAUwBVADgARAB3AFEAVAAxAFEAPQA9AHwAOQBmADQANQA4AGUANQBlAGUAZQBmAGEAMgA5ADAAYwAyADgAYQAwAGUAYQAyADYANABkADgAOABiADMAMgA1ADkANQA1AGIANwA2AGUAOQBjADcANgA0AGYAOQAzAGYANgAzADAANgA0ADUAMQA2ADIAYwBhAGEAYwBhAGYAMQA1ADYAMQA1ADEAZAA2ADMANABkAGQAZQBkADAANgBiAGEANQA1ADAAZABhAGIAYQA4ADMAZgA0ADMAMwBiADEAZABjAGMANABiAGUAZAAzADQAYgA3ADMAMQA4AGEAZQBkADAAYgBlAGQANgBkADMAYgA2ADAANwA2ADEAMQA4AGMANwAyADMAOQA4ADgAYwA2ADIAMQAwAGUAZgBhADQAMwAwADUAOABlAGYAMABiADQAYgA4ADAAYwAwAGQANQBlADIAMwA5AGIAMgBkADIANwBjADEAZQBhADEAYgA0AGEANABiAGQAZgBiAGYAOQAyAGQAZAA0AGUAOQA1AGUAMQBkADgANABiAGQAMgAxADMAYgAxADQANwAxAGYAOQBhADgAYwAzAGQAZQBmAGIAYgA3ADEAYwBkADAAYwBkADcAMABiADAAMAA3AGQANABiAGQAYQAzADkAYgAyADcAOQBhADYAYQA4AGMAZgA5ADkAZAA2ADkANQBiADUAOQA0ADIAOAA2AGEAYgAyAGYANQBmADcANQBjADMAZAA3ADEAZAAwADUAZQAyADYAMAA1AGEAMwBjADAAZQBlADQAYQA4AGQAZQA4ADUAOQBjADgAOQBiADgAOQA0ADMAOAAyAGIAZQAwAGMAOABhADYAMQAyAGMANgAyADQAZgA5ADUAMAA5AGYAYQAxADMANgBmADUAMQBkADEAMwAzADIAOQBhADcANAA2AGYAYgA5ADEAMAA4ADMAMgA5ADgAYQAwADMAYQA3ADMANwBmADYANgA2ADEAMQAwADcANAA0AGUAYQA5ADIANgAwADcAYgBhADQANwBmAGEAOQBlADMAMgBkAGMAYwBkADQAYgBhADEAOAA5ADkAOAA4ADMAZAAzAGEAMwBiAGQANAA4AGMAMQAzAGEAZQBiADYANgA3ADYAYwA2ADAAOQAyADUAYQBjADMANwBhAGUAZgBjAGMAOAA2ADEAYwAyADkAMQBhAGQANAA5AGUAOQBkADUANAAzADQANgAzADEANAAyADIAMwAwADYANwA5AGQAOAA3ADYAYgAyAGEAOAA1AGQAMABlAGYAZgA3ADkANgBiADQANAA3ADQAZQA1ADEAZQBhADYAZQAwADIAYgA3ADYAYwA0ADQAOABiADkANAA1AGIAYgBkAGIAYgAxAGUANABhADYAMgAxADUAMQAzAGYAMgBjAGQAZgBjAGQAMQBjAGYAOQBkAGUAOQA1AGEANQA2ADUAMwBhADkAMQA3ADUAOAA5ADEAOAAyAGUAMgA2ADQAYQA1AGYAYgBlAGIANAA3AGUANgBmAGIAMgAxADgAYwBkADIAMAAwAGYAZAAzADUAMABiADcAOQA2ADYAYgBmADcANgA4AGUAYQBkAGEAMgA1AGIAYwBhAGYAZgA0ADgAMQA1ADcAYgAxADgAYgA4AGQAOAAyADgANAAzADYANQAxAGEAOABlAGMAZQBmAGIANAAxADUAYwBmADQAMQAxADkAOQBjADgAMABhADIAYQA5AGEAMwA5ADgAYwBkADkAYgAxADAAYQA2ADMAOQAwADIAMABkADgAMQAxADIANwAyAGYAYwBiADEAYwA4ADYAMABhADcAOQBlAGMAZABkADAANQA4ADYAMwAwAGYANwBhADgAOQA3AGUAMgAxADgAYwBjADkANgBjAGIAZQBjAGQAMAA4AGIAYgA1ADgAOABiADIAOQBmAGEAMgAyAGYAZQA1ADYAMwBiAGIAYgBmAGUAMgBiADEAZAA2ADMAYgAyADkAMQA3AGMANAA1ADMANAAzAGUAYgAyADkAMwBhADMAMQAzAGYAYQBiAGIAYwA0ADcAYQA3ADYAYQAyADkAZgBkADIAMwBlADgAZgAyADkAOQA0AGQANAA0ADIANwAzADEAOAAyADkAZQA0ADkAZgA4ADQAMgA3AGEAYwAxADEANAA2ADMAMgA3ADAAYQAyADkANAAzADEAMQA0AGYAMAA0ADcAYwBlADMAOQBhADgAMgA1ADcAYQA4ADYANAAwAGIAYQA3AGMAYwA2ADkAMgA5ADUAMgBhADYAZgAzAGEAMwAwADgAMQA0ADgAMgBiAGQAYgA2AGEAZgBiAGQAOABiAGIAZABmADgAZQA1AGIAYwAwADYAMgAxAGEANABjADkAZAAzADIAYgBkADYAMwA1ADgAMgA5AGEAYQBiADkANAA1AGUAYgAxAGIAYQBjADEAOAA5AGEAYwBjADIAYQA5AGEAMAA3ADQAYwA2AGUAOAA4ADAAOQAwADAAYwAyADkAMAAxAGEAMgA1AGEANABmAGEAYwAzADkAOABmADEAOQAzADgAYgA5ADQAOAA2AGQAZgA1ADAAZgBhADAAZgBjADgAYgAzAGEANQAwADEAZgBjADEAZQAwADYAOQAzADkAOAA5ADIANQAyAGIANQAzAGMAYwA4ADEAYgA4ADUAMAA1AGYAZQAxADkAZQBhADgAMgA0ADkAYQAwAGEAOQBmADMAMwBjADcAOQA5AGUAZABjAGUAMQAzADEAMABiADIANwA4ADMANwAwADMANQA4ADMAYgBlADgANgA2ADUANwAyADYAZgA4AGYAOAAwAGQAZAA1ADgAYwBjADAAZAAwADkAZABkAGIAZgBlAGEAMgAwAGMAZAA2ADQAMwA0ADYAZgBkADgAYwBjAGMAYgBiADAAMQAzADYAMABiADkAZQBiADUAYQBjAGEANAA4AGUAOAAxADUAMABlAGYANQAwADIAYgAxAGQAMAAxAGQAZABkADkAOQA5AGQAMgA0AGQAZQAyAGMAOQA4ADMANQBmADUANgA3ADQAMgAyADEAZABkADEAOABjADkAZgAzADkANgBhADIAYwBmADcAMgAxADcAMQA4AGYAYgBjAGYANQBmADUAMQA0AGYAMQAyADEAYwAzADMAZQA3ADEAYwA2AGUAOQAxADgANwA4ADkAZgBkAGUAMAA1ADUAZABmADcANgBiADUANgA1ADEANAAxADUAYwBlADkAMgA4AGYANwA0AGMANwAxADcAOQBiADAAZQBjAGQAMwAzAGUAOQBiADcAZgBhAGEAOQBmADkAZQA1AGYAOAA2AGEANgBlADIAOQA2ADkAZQA3ADAAOAA1AGYAYQBhADYANQBjADQAZQA1ADcAMgA2AGYANQBjADcAOABlAGYAZAAxAGUAMAA4AGMANwAwAGUAMwA3AGUANAAxADEAMABmADkAMQBlAGIAYwBjAGIAYwBhAGEANgA0AGQANwBkAGQAMwAzADIANwBlADIAZQBlAGEAMABhAGMAYQBmAGUAZgA0AGIANwA5ADcAZgBlADEAZABjADEAOQBhAGMAYgA1ADIANQAyADYAYQAwAGYAYwAxAGMAOQAxADEAMwAwADcANgA0AGQAOABiADUANgA2AGEANAA2ADQAMwA2ADUAZAA2AGUAZgA0ADgANABkADkANQAxADIANwBkADcAMgBkAGUAMgA1AGUAYQAxADQAZQAwADIAYgBkAGYANQBhAGIANABjADAAOAA5ADUAZgBmAGMANgA1ADQANAA1ADcAZQAxAGYANQBlAGYAMwAwADcAOABmADcANgAwAGQAMAA3AGMAMQBhADYAMQBmADMANgAwADYAMAA4ADEAMgAyADQAMAA3ADEANQA4ADgANgBjAGQANwBhADAAMQA2ADQANgAwADQAOQBiADEANwA1ADAAZAA0ADkAMwBmADcANQA3ADAAYgBjAGIANgAxADUAMQAwAGYAOQA2AGUAMQAwADIANAAyADAAMgBiAGYANgAwADAANgAzAGUAZgAxADAAYgBiADEAOQBlAGMAOAA2ADcAMAAyADIAYwA0AGUAMAA4ADMAMAAyAGUAZgAyAGEANwAxAGMAOQA2ADQANwA2ADEAOQBkAGMAMwBiADYAOQA1ADkAYgA4AGUANABjAGEAMgBjADQAZABjAGQAOAA4ADEAYgBmADkAZQA0AGYAZQAwAGIANwA5ADkANgBiAGIAYwBhAGMANAA3ADEAZAAwADQANgAzADkANAA4ADEAYgBjADUAYQA4ADYANgAzADMANQA3AGUANAAxAGYAOAAwAGQAZQBmADkAOQBlAGQANQBiAGYAOABlADgAMgBmAGYAYQA3ADMAYgBkADEAYwBhAGMAYgBkAGIAYgA3ADEAZQAwADUAMQA4ADkAMgA5ADUAYQBlADMANwA2AGQAYQBkADIAYQBiADMANgAwAGUAYQAwADYAZQA5AGMAYgAxADQANwA3ADQAZQAwADgAYQAyADEAMwA2ADUAOABjADkAYgAyAGMAOQA2AGQANQA1ADQAMQAwAGEAMQBmADQAYgA1AGEAMgA5AGQAMwA2ADcAMQAzADIAYgBhAGEAOAA0ADcAMwAwADgANwAzAGQAOABlADIAYgAyADMAZABmAGEAZAAxADYAMQBiADYAYQAyADUANABhADcAOQAzADkAMwAwAGQAZgAxADYAYQA3ADgAYgAxADYANAA3ADgANQA4AGYANABiAGEAYgA1AGIAMgAzAGMAMAA5ADAAZQA4ADEAOABmADMAMAA1AGIAMAA0ADIAMwAxAGUAOABlADQAMQBmAGEAZQAwADAAMgAwAGUAZQBjAGIAMgAwAGEAYQA3ADkAOAA2AGEANAAzADkAMQAxAGMAOQA3ADQANgA4AGQAZgA2AGMAZgA1ADEAZQAzADcANwAxADMAZgAzAGEANwAxAGUAZABiAGYAYwA5AGYAOQA2ADMAOQA2ADYAZAA5AGEAZABlADMAZQBlADEAOABjADcANABlAGUAMAAzADAAYQAwADYAZQBlADcAZABmADAAZQBhADIANQA5ADgANgA4ADcAYwA5ADEAYQA0ADcAYwBlADEANAA1AGMAYQA2AGMAZAA5AGYANgA4ADEAZABiAGEAZAA0ADAAZAA1ADYAMwBlAGEANgBjADcAMgBiAGQAMQA0AGYAYQBjAGQAYwA0ADkANgBjAA=="

    mailSecureString = "76492d1116743f0423413b16050a5345MgB8ADQARQByAEgANABpAEcAYgBEAHgAQQBDAGYAZgBYAHQATgB5AHUAbgBDAEEAPQA9AHwAYwAxADYANwA0ADAAYQAyADUAZABmADQAMwA4AGUAZQA2ADIAOAA0ADcAZABmADEAYQBlADIAZABhADgAYgA0ADcANgA0ADAAZAA2ADEANwA0ADYANgBmADEAMABiADAAMwA1ADYAMwAzADYAMgA5AGMAYgAwADAAOQA2AGQAZABiADQAMgBkAGMAZgA0ADAAMQBmADUANQAwAGEAMwBhADEAMQA4ADMAMAAwADEAOQBiADcANAAxADIAMgAwADkA"

    base = "https://rest.cleverreach.com/v3/"
    #loadArchivedRecords = $true
    pageLimitGet = 5000 # Max amount of records to download with one API call
    exportDir = "$( $scriptPath )\extract\$( Get-Date $timestamp -Format "yyyyMMddHHmmss" )_$( $processId )\"
    backupDir = "$( $scriptPath )\backup"
    sqliteDb = "C:\Apteco\Build\Hubspot\data\cleverreach.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    filterForSqliteImport = @("*.csv";"*.txt";"*.tab")
    logfile = "$( $scriptPath )\cleverreach_extract.log"
    backupSqlite = $true # $true|$false if you wish to create backups of the sqlite database
    
    createBuildNow = $false # $true|$false if you want to create an empty file for "build.now"
    #buildNowFile = "C:\Apteco\Build\Hubspot\now\build.now" # Path to the build now file

    # Settings for smtp mails
    mailSettings = @{
        smtpServer = "smtp.ionos.de"
        from = "admin@crm.apteco.io"
        to = "florian.von.bracht@apteco.de"
        port = 587
    }

    # details to load from cleverreach per receiver
    cleverreachDetails = @{
        events = $true
        orders = $false
        tags = $true
    }
    
}


# Create the binary value for loading the cleverreach details for each receiver
$cleverreachDetailsBinaryValues = @{
    events = 1
    orders = 2
    tags = 4
}
$cleverReachDetailsBinary = 0
$cleverreachDetailsBinaryValues.Keys | ForEach {
    if ( $settings.cleverreachDetails[$_] -eq $true ) {
        $cleverReachDetailsBinary += $cleverreachDetailsBinaryValues[$_]
    }
}

# Items to backup
$itemsToBackup = @(
    "$( $settings.sqliteDb )"
)

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

# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
}


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################


# Create general settings
$keyfilename = $settings.aesFile
$auth = "Bearer $( Get-SecureToPlaintext -String $settings.token )"
$header = @{ "Authorization" = $auth }
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp


# Create credentials for mails
$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext -String $settings.mailSecureString ) -AsPlainText -Force
$smtpcred = New-Object PSCredential $settings.mailSettings.from,$stringSecure

# Exit for manually creating secure strings
# exit 0
#

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
# CHECK CONNECTION AND LOGIN
#
################################################

$ping = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/ping.json" -Headers $header -Verbose

$validAUth = Invoke-RestMethod -Method Get -Uri "$( $settings.base )debug/validate.json" -Headers $header -Verbose


# Exit if no limit is delivered
if ( $ping -and $validAuth ) {
    
    Write-Log -message "Connection succeeded. Quote of CleverReach: $( $ping )"

} else {
    
    Write-Log -message "No connection available -> exit"
    throw [System.IO.InvalidDataException] "No connection and/or valid authentication available"
    
}


################################################
#
# DOWNLOAD BLACKLIST
#
################################################

Write-Log -message "Downloading the blacklist"

# write the black list
$blacklist = Invoke-RestMethod -Method Get -Uri "https://rest.cleverreach.com/v3/blacklist.json" -Headers $header

Write-Log -message "Found $( $blacklist.Count ) entries"


################################################
#
# DOWNLOAD GROUP METADATA
#
################################################

Write-Log -message "Downloading all groups/lists"

# get all groups
$groupsUrl = "$( $settings.base )groups.json"
$groups = Invoke-RestMethod -Method Get -Uri $groupsUrl -Headers $header

Write-Log -message "Found $( $groups.Count ) groups"


################################################
#
# DOWNLOAD MAILINGS METADATA
#
################################################

Write-Log -message "Downloading all mailings"

# get all mailings
$mailingsUrl = "$( $settings.base )mailings.json?state=finished"
$mailings = Invoke-RestMethod -Method Get -Uri $mailingsUrl -Headers $header

Write-Log -message "Found $( $mailings.Count ) mailings"


################################################
#
# DOWNLOAD ALL GROUPS RECEIVERS
#
################################################

# Download all data and one call per group

# write all single groups and additional attributes
$detailLevel = $cleverReachDetailsBinary # Detail depth (bitwise combinable) (0: none, 1: events, 2: orders, 4: tags).
$attributes = Invoke-RestMethod -Method Get -Uri "$( $settings.base )attributes.json" -Headers $header -Verbose # load global attributes first
$contacts = @()
$groups | ForEach {
    
    $groupId = $_.id
    $page = 0
    Write-Log -message "Downloading group id $( $groupId )"
    
    # Downloading attributes
    $attributes += Invoke-RestMethod -Method Get -Uri "$( $groupsUrl )/$( $groupId )/attributes" -Headers $header -Verbose # add local attributes

    do {

        $url = "$( $groupsUrl )/$( $groupId )/receivers?pagesize=$( $settings.pageLimitGet )&page=$( $page )&detail=$( $detailLevel )"
        $result = Invoke-RestMethod -Method Get -Uri $url -Headers $header -Verbose

        $contacts += $result
        
        Write-Log -message "Loaded $( $contacts.count ) 'contacts' in total"

        $page += 1

    } while ( $result.Count -eq $settings.pageLimitGet )
    
}

Write-Log -message "Done with downloading $( $contacts.count ) 'contacts' in total"

#$contacts | Out-GridView

################################################
#
# FILTER ALL RECEIVERS
#
################################################


<#
# Download all receivers all in once, but contains some problems -> no local attributes and no tags yet
    
$filter = [ordered]@{
    groups = @()
    operator = "OR"
    rules = @(
        [ordered]@{
            field = "email"
            logic = "notisnull"
            #condition = "florian.von.bracht@apteco.de"
        }
    )
    detail = $cleverReachDetailsBinary # Detail depth (bitwise combinable) (0: none, 1: events, 2: orders, 4: tags).
    pagesize = $settings.pageLimitGet
    page = 0
}

$receiver = @()
$page = 0   
do {
    
    $filterJson = $filter | ConvertTo-Json -Depth 8 -Compress
    $url = "https://rest.cleverreach.com/v3/receivers/filter.json"
    $result = Invoke-RestMethod -Method Post -Uri $url -Headers $header -Verbose -Body $filterJson -ContentType "application/json"

    $receiver += $result #| select * -ExcludeProperty attributes #| Select email -expand global_attributes

    $filter.page += 1

} while ( $result.Count -eq $settings.pageLimitGet )
    
#$receiver | Out-GridView

#>


################################################
#
# EXPORT DATA INTO CSV
#
################################################

Write-Log -message "Exporting the data into CSV and creating a folder with the id $( $processId )"

# Create folder
New-Item -Path $settings.exportDir -ItemType Directory

# The blacklist - only current values
$blacklist | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )blacklist.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All groups - keep history
$groups | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )groups.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All global and local attributes - only current values
$attributes | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )attributes.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# Currently finished mailings - keep history
$mailings.finished | select * -ExcludeProperty body_html, body_text, mailing_groups | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )mailings__finished.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# Ids of mailings and groups (could be multiple groups) - keep history
$mailings.finished | select id -ExpandProperty mailing_groups | Format-Array -idPropertyName "id" -arrPropertyName group_ids | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )mailings__groups.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All contacts
$contacts | select * -ExcludeProperty events, tags, orders, global_attributes,attributes | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )receivers.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All local attributes for all receivers - only current values
$contacts | where { $_.attributes.psobject.properties.count -gt 0 } | select id, group_id -ExpandProperty attributes | Format-KeyValue -idPropertyName "id" -removeEmptyValues | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )groups__attributes__local.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All global attributes for all receivers - only current values
$contacts | select -Unique id, global_attributes | select id -ExpandProperty global_attributes | Format-KeyValue -idPropertyName "id" -removeEmptyValues | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )groups__attributes__global.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# All events for all receivers (opens, clicks, bounces. logs etc.) - keep history
if ( $settings.cleverreachDetails['events'] ) {
    $contacts | where { $_.events.count -gt 0 } | select -Unique id, events | select id -ExpandProperty events | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )receivers__events.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
    #$mailingEvents = $events | where { $_.mailing_id -ne 0 }
    #$groupsEvents = $events | where { $_.groups_id -ne 0 }
    #$otherEvents =  $events | where { $_.mailing_id -eq 0 -and $_.groups_id -eq 0 }
}

# All tags for all receivers - only current values
if ( $settings.cleverreachDetails['tags'] ) {
    $contacts | where { $_.tags.count -gt 0 }  | select -Unique id, tags | Format-Array -idPropertyName "id" -arrPropertyName "tags" | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )receivers__tags.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
}

# All orders for all receivers - only current values
# TODO [ ] NOT IMPLEMENTED AND TESTED YET
if ( $settings.cleverreachDetails['orders'] ) {
    $contacts | where { $_.orders.count -gt 0 }  | select -Unique id, orders | select id -ExpandProperty orders | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )receivers__orders.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
}

Write-Log -message "Exported $( (Get-ChildItem -Path $settings.exportDir).Count ) files with the id $( $processId )"


################################################
#
# BACKUP SQLITE FIRST
#
################################################

Write-Log -message "Setting for creating backups $( $settings.backupSqlite )"

if ( $settings.backupSqlite ) {
    
    # TODO [ ] put these into settings
    

    # Create backup subfolder
    $destination = $settings.backupDir
    $destinationWithTimestamp = "$( $destination )\$( Get-Date $timestamp -Format "yyyyMMddHHmmss" )_$( $processId )\"
    New-Item -Path $destinationWithTimestamp -ItemType Directory

    Write-Log -message "Creating backup into $( $destinationWithTimestamp )"

    # backup
    $itemsToBackup | foreach {

        $source = $_
        
        # Check if it is a file or folder
        if ( Test-Path -Path $source -PathType Leaf ) {
            # File
        } else {
            #Folder
            $source = "$( $source )\*"
        }

        Write-Log -message "Creating backup of $( $source )"    

        Copy-Item -Path $source -Destination $destinationWithTimestamp -Force -Recurse

    }

}


################################################
#
# LOAD CSV INTO SQLITE
#
################################################

# TODO [ ] make use of transactions for sqlite to get it safe

Write-Log -message "Import data into sqlite '$( $settings.sqliteDb )'"    

# Settings for sqlite
$sqliteExe = $libExecutables.Where({$_.name -eq "sqlite3.exe"}).FullName
$processIdSqliteSafe = "temp__$( $processId.Guid.Replace('-','') )" # sqlite table names are not allowed to contain dashes or begin with numbers
$filesToImport = Get-ChildItem -Path $settings.exportDir -Include $settings.filterForSqliteImport -Recurse

# Create database if not existing
# In sqlite the database gets automatically created if it does not exist

# Import the files temporarily with process id
$filesToImport | ForEach {
    
    $f = $_
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"

    # Import data
    ImportCsv-ToSqlite -sourceCsv $f.FullName -destinationTable $destination -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 

    # Create persistent tables if not existing
    $tableCreationStatement  = ( Read-Sqlite -query ".schema $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false ) -replace $destination, "IF NOT EXISTS $( $f.BaseName )"
    $tableCreation = Read-Sqlite -query $tableCreationStatement -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false

    Write-Log -message "Import temporary table '$( $destination )' and create persistent table if not exists"    

}

# Import data from temporary tables to persistent tables
$filesToImport | ForEach {
    
    $f = $_
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"

    Write-Log -message "Import temporary table '$( $destination )' into persistent table '$( $f.BaseName )'"    


    # Column names of temporary table    
    $columnsTemp = Read-Sqlite -query "PRAGMA table_info($( $destination ))" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 

    # Column names of persistent table
    $columnsPersistent = Read-Sqlite -query "PRAGMA table_info($( $f.BaseName ))" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    $columnsPersistensString = $columnsPersistent.Name -join ", "

    # Compare columns
    $differences = Compare-Object -ReferenceObject $columnsPersistent -DifferenceObject $columnsTemp -Property Name
    $colsInPersistentButNotTemporary = $differences | where { $_.SideIndicator -eq "<=" }
    $colsInTemporaryButNotPersistent = $differences | where { $_.SideIndicator -eq "=>" }

    # Add new columns in persistent table that are only present in temporary tables
    if ( $colsInTemporaryButNotPersistent.count -gt 0 ) {
        Send-MailMessage -SmtpServer $settings.mailSettings.smtpServer -From $settings.mailSettings.from -To $settings.mailSettings.to -Port $settings.mailSettings.port -UseSsl -Credential $smtpcred
                 -Body "Creating new columns $( $colsInTemporaryButNotPersistent.Name -join ", " ) in persistent table $( $f.BaseName ). Please have a look if those should be added in Apteco Designer." `
                 -Subject "[CRM/Hubspot] Creating new columns in persistent table $( $f.BaseName )"
    }
    $colsInTemporaryButNotPersistent | ForEach {
        $newColumnName = $_.Name
        Write-Log -message "WARNING: Creating a new column '$( $newColumnName )' in table '$( $f.BaseName )'"
        Read-Sqlite -query "ALTER TABLE $( $f.BaseName ) ADD $( $newColumnName ) TEXT" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    
    }

    # Add new columns in temporary table
    # There is no need to do that because the new columns in the persistent table are now created and if there are columns missing in the temporary table they won't just get filled.
    # The only problem could be to have index values not filled. All entries will only be logged.
    $colsInPersistentButNotTemporary | ForEach {
        $newColumnName = $_.Name
        Write-Log -message "WARNING: There is column '$( $newColumnName )' missing in the temporary table for persistent table '$( $f.BaseName )'. This will be ignored."
    }

    # Import the files temporarily with process id
    $columnsString = $columnsTemp.Name -join ", "
    Read-Sqlite -query "INSERT INTO $( $f.BaseName ) ( $( $columnsString ) ) SELECT $( $columnsString ) FROM $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    

}

# Drop temporary tables
$filesToImport | ForEach {  
    $f = $_
    $destination = "$( $processIdSqliteSafe )__$( $f.BaseName )"
    Read-Sqlite -query "Drop table $( $destination )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    Write-Log -message "Dropping temporary table '$( $destination )'"
}  


################################################
#
# CREATE SUCCESS FILE
#
################################################

if ( $settings.createBuildNow ) {
    Write-Log -message "Creating file '$settings.buildNowFile'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.buildNowFile -Encoding utf8 -Force
}

