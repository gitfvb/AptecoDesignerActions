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

$debug = $false



################################################
#
# NOTES
#
################################################

<#



To get started -> replace the initial refresh token e.g. from postman with the folling settings:
Callback URL: https://www.apteco.de
Auth URL: https://api.getgo.com/oauth/v2/authorize
Access Token URL: https://api.getgo.com/oauth/v2/token
Client ID: <clientIdSeeKeePass>
Client Secret: <clientSecretSeeKeePass>
Scope: collab:
Client Authentication: Send as Basic Auth Header

Then go further and create the encrypted client secret with the command
Get-PlaintextToSecure "<clientSecret>"
This command is also included later with an "exit 0" to find the right point that all needed dependencies are loaded first

refresh token valid for 30 days

During application development the default rate limit is 100 calls per second per application, 10 calls per second per method, and a total of 500 calls per day. 

#>

# TODO [ ] Implement webhooks for realtime usage

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
#$settingsFilename = "settings.json"
#$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()
$modulename = "gotowebinar_extract"
$timestamp = [datetime]::Now

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

$settings = @{

    # Security settings
    aesFile = "$( $scriptPath )\aes.key"

    # HINT: obtain the token with the scope "collab:"

    session = @{
        file = "$( $scriptPath )\session.json"
        #ttl = 3600 # Seconds
        initialRefreshToken = "<initalRefreshToken>"
        clientId = "<clientId>"
        clientSecret = "<clientSecretEncrypted>"
        encryptToken = $true
    }


    base = "https://api.getgo.com/"

    exportDir = "$( $scriptPath )\extract\$( Get-Date $timestamp -Format "yyyyMMddHHmmss" )_$( $processId )\"
    backupDir = "$( $scriptPath )\backup"
    sqliteDb = "D:\Apteco\Build\GoToWebinar\data\gotowebinar.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    filterForSqliteImport = @("*.csv";"*.txt";"*.tab")
    logfile = "$( $scriptPath )\gotowebinar_extract.log"
    backupSqlite = $true # $true|$false if you wish to create backups of the sqlite database
    
    createBuildNow = $false # $true|$false if you want to create an empty file for "build.now"
    #buildNowFile = "D:\Apteco\Build\Hubspot\now\build.now" # Path to the build now file

    # Settings for smtp mails
    mailSettings = @{
        smtpServer = "smtp.ionos.de"
        from = "admin@crm.apteco.io"
        to = "florian.von.bracht@apteco.de"
        port = 587
    }
    

}


# Items to backup
$itemsToBackup = @(
    "$( $settings.sqliteDb )"
)

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
    $settings.sqliteDb = "$( $settings.sqliteDb ).debug"
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

# Exit point for creating secure strings
# Get-PlaintextToSecure "<clientSecret>"
#exit 0

Get-GoToSession

if ( $settings.session.encryptToken ) {
    $token = Get-SecureToPlaintext -String $Script:sessionId
} else {
    $token = $Script:sessionId
}

$auth = "Bearer $( $token )"
$headers = @{ "Authorization" = $auth }
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp

# Create credentials for mails
#$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext -String $settings.mailSecureString ) -AsPlainText -Force
#$smtpcred = New-Object PSCredential $settings.mailSettings.from,$stringSecure



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
# PROGRAM
#
################################################


#-----------------------------------------------
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

#Get-GoToSession

#exit 0



$webinars = Invoke-RestMethod -Method Get -Uri "$( $settings.base )G2W/rest/organizers/$( $Script:organizer )/webinars" -Headers $headers -ContentType "application/json" -Verbose
$upcomingWebinars = Invoke-RestMethod -Method Get -Uri "$( $settings.base )G2W/rest/organizers/$( $Script:organizer )/upcomingWebinars" -Headers $headers -ContentType "application/json" -Verbose
$historicalWebinars = Invoke-RestMethod -Method Get -Uri "$( $settings.base )G2W/rest/organizers/$( $Script:organizer )/historicalWebinars?fromTime=2020-01-01T12:00:00Z&toTime=2020-05-31T13:00:00Z" -Headers $headers -ContentType "application/json" -Verbose








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
# EXPORT DATA INTO CSV
#
################################################

Write-Log -message "Exporting the data into CSV and creating a folder with the id $( $processId )"

# Create folder
New-Item -Path $settings.exportDir -ItemType Directory

$webinars | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )webinars.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
$upcomingWebinars | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )upcoming.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
$historicalWebinars | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )historic.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

Write-Log -message "Exported $( (Get-ChildItem -Path $settings.exportDir).Count ) files with the id $( $processId )"





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
# CREATE SUCCESS FILES
#
################################################

if ( $settings.createBuildNow ) {
    Write-Log -message "Creating file '$( $settings.buildNowFile )'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.buildNowFile -Encoding utf8 -Force
}

if ( $settings.createNoMoreResponse -and $noMoreReportsResponse -ne $true) {
    Write-Log -message  "Creating 'no more reports response' file '$( $settings.createNoMoreResponseFile )'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.createNoMoreResponseFile -Encoding utf8 -Force
}


################################################
#
# SEND EMAIL
#
################################################

exit 0

$password = ConvertTo-SecureString 'xxx' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('xxx@xxx.de', $password) 
Send-MailMessage -SmtpServer "xxx" -From "xxx" -To "xxx" -Subject "[CLEVERREACH] Data was extracted from CleverReach and is ready to import" -Body "xxx" -Port 587 -UseSsl -Credential $credential
