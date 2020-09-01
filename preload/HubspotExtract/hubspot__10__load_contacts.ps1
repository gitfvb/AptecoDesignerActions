################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        scriptPath = "C:\Apteco\Build\Hubspot\preload\HubspotExtract"
    }
}


################################################
#
# NOTES
#
################################################



<#

Links
https://developers.hubspot.com/docs/methods/contacts/v2/get_contacts_properties
https://developers.hubspot.com/docs/api/crm/contacts

#>



################################################
#
# SCRIPT ROOT
#
################################################

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
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
$modulename = "hubspot_extract"
$timestamp = [datetime]::Now

# Load last session
#$lastSession = Get-Content -Path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
#$logfile = $settings.logfile
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

# TODO  [ ] unify settings in json file
$settings = @{

    # Security settings
    aesFile = "$( $scriptPath )\aes.key"

    # Create a secure string like
    # Get-PlaintextToSecure -String "token" -keyFile "$( $scriptPath )\aes.key"
    # And get it plaintext back by
    # Get-SecureToPlaintext -String $settings.token 
    token = "76492d1116743f0423413b16050a5345MgB8AEkAQgBSAFIATABDADgAbgBuAFoAUgBkADEAYwAxAGkAVgBIAHQAUwA4AFEAPQA9AHwAMAA4ADIANABkADQANwA5AGQAMABhADIAYwA5AGEAZABhAGUANQAzAGMANgA1ADIANgA5ADkAZABlAGQAOAAzAGEAOQBlADQAZAAyADMAZgA5ADQANQA2AGQAMwA4AGIAYgAwADIAMQAxADMANQA1AGYANQAwAGQAYQA2ADAANAA4AGQAMwBkADQAYwAzADEAMQA1AGYANQAxADcAZgA4ADMANwAzAGIAOAAyADAAOABjADUAMgBlADUAZgA4ADQAYgBmADAAMgA3ADAAOQAyADkAMQAxAGEAZgBhADEAMgA3ADAAYQA3ADEANwAyADUAMQA2AGMANwBiADAAZQA1ADQAOQBjAGYAZAAxADYANAA1ADMAMQBkADEAMgA4ADcANQBmAGIAZgAxAGEAZABmAGEAZgBjADMANQBiADkAMwA="
    mailSecureString = "76492d1116743f0423413b16050a5345MgB8ADQARQByAEgANABpAEcAYgBEAHgAQQBDAGYAZgBYAHQATgB5AHUAbgBDAEEAPQA9AHwAYwAxADYANwA0ADAAYQAyADUAZABmADQAMwA4AGUAZQA2ADIAOAA0ADcAZABmADEAYQBlADIAZABhADgAYgA0ADcANgA0ADAAZAA2ADEANwA0ADYANgBmADEAMABiADAAMwA1ADYAMwAzADYAMgA5AGMAYgAwADAAOQA2AGQAZABiADQAMgBkAGMAZgA0ADAAMQBmADUANQAwAGEAMwBhADEAMQA4ADMAMAAwADEAOQBiADcANAAxADIAMgAwADkA"

    base = "https://api.hubapi.com/"
    loadArchivedRecords = $true
    pageLimitGet = 100 # Max amount of records to download with one API call
    exportDir = "$( $scriptPath )\extract\$( Get-Date $timestamp -Format "yyyyMMddHHmmss" )_$( $processId )\"
    backupDir = "$( $scriptPath )\backup"
    sqliteDb = "C:\Apteco\Build\Hubspot\data\hubspot.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    filterForSqliteImport = @("*.csv";"*.txt";"*.tab")
    logfile = "$( $scriptPath )\hubspot_extract.log"
    backupSqlite = $true # $true|$false if you wish to create backups of the sqlite database
    
    createBuildNow = $true # $true|$false if you want to create an empty file for "build.now"
    buildNowFile = "C:\Apteco\Build\Hubspot\now\build.now" # Path to the build now file

    # Settings for smtp mails
    mailSettings = @{
        smtpServer = "smtp.ionos.de"
        from = "admin@crm.apteco.io"
        to = "florian.von.bracht@apteco.de"
        port = 587
    }

}

$itemsToBackup = @(
        "$( $settings.sqliteDb )"
    )

<#
# TODO [ ] load token from Designer environment variable
$token = Get-SecureToPlaintext -String $settings.token 
$settings.base = "https://api.hubapi.com/"
$loadArchivedRecords = $true
$pageLimitGet = 100 # Max amount of records to download with one API call
$exportDir = "$( $scriptPath )\extract\$( $processId )\"
$sqliteDb = "C:\Apteco\Build\Hubspot\data\hubspot.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
$filterForSqliteImport = @("*.csv";"*.txt";"*.tab")
#>

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
$hapikey = "&hapikey=$( Get-SecureToPlaintext -String $settings.token )"

# Create credentials for mails
$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext -String $settings.mailSecureString ) -AsPlainText -Force
$smtpcred = New-Object PSCredential $settings.mailSettings.from,$stringSecure

exit 0

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
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################

# Load last session
If ( Check-Path -Path "$( $scriptPath )\$( $lastSessionFilename )" ) {
    $lastSession = Get-Content -Path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
    $lastTimestamp = $lastSession.lastTimestamp
    $extractMethod = "DELTA" # FULL|DELTA

    Write-Log -message "Last timestamp: $( $lastTimestamp )"
    Write-Log -message "Pretty timestamp: $( Get-Date ( Get-DateTimeFromUnixtime -unixtime $lastTimestamp -inMilliseconds -convertToLocalTimezone ) -Format "yyyyMMdd_HHmmss" )"

} else {
    $extractMethod = "FULL" # FULL|DELTA
}

Write-Log -message "Chosen extract method: $( $extractMethod )"

#$lastTimestamp = Get-Unixtime -timestamp ( (Get-Date).AddMonths(-1) ) -inMilliseconds
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
$currentTimestampDateTime = Get-DateTimeFromUnixtime -unixtime $currentTimestamp -inMilliseconds -convertToLocalTimezone


Write-Log -message "Current timestamp: $( $currentTimestamp )"





################################################
#
# CHECK CONNECTION AND LIMITS
#
################################################


$object = "integrations"
$apiVersion = "v1"

$url = "$( $settings.base )$( $object )/$( $apiVersion )/limit/daily?$( $hapikey )"
$limits = Invoke-RestMethod -Method Get -Uri $url #-Headers $headers

# Current usage
$currentApiUsage = $limits.currentUsage

# Current limit
$currentApiLimit = $limits.usageLimit

# Exit if no limit is delivered
if (!($currentApiLimit -gt 0)) {
    Write-Log -message "No connection available -> exit"
    throw [System.IO.InvalidDataException] "No connection available"
} else {
    Write-Log -message "Connection succeeded. Current api usage: $( $currentApiUsage ) / $( $currentApiLimit )"
}



################################################
#
# LOAD CONTACTS PROPERTIES
#
################################################


$object = "properties"
$apiVersion = "v1"
$url = "$( $settings.base )$( $object )/$( $apiVersion )/contacts/properties?$( $hapikey )"

$properties = Invoke-RestMethod -Method Get -Uri $url

# Find out different types of properties
$propertiesGroups = $properties | select -Unique groupName

# Show properties
#$properties | sort groupName | Out-GridView

#$allProperties = $properties.name -join ","

Write-Log -message "Loaded $( $properties.count ) 'contacts' properties and $( $propertiesGroups.count ) property groups"


################################################
#
# LOAD CONTACTS
#
################################################

Switch ( $extractMethod ) {
    
    "FULL" {
        

        #-----------------------------------------------
        # FULL ACTIVE CONTACTS
        #-----------------------------------------------

        $object = "crm"
        $apiVersion = "v3"
        $limit = $settings.pageLimitGet
        $archived = "false"
        $url = "$( $settings.base )$( $object )/$( $apiVersion )/objects/contacts?limit=$( $limit )&archived=$( $archived )&properties=$( $properties.name -join "," )$( $hapikey )"

        $contacts = @()
        Do {
    
            # Get all contacts
            $contactsResult = Invoke-RestMethod -Method Get -Uri $url -Verbose
    
            # Add contacts to array
            $contacts += $contactsResult.results

            Write-Log -message "Loaded $( $contacts.count ) 'contacts' (currently non-archived) in total"

            # Load next url
            $url = "$( $contactsResult.paging.next.link )$( $hapikey )"

        } while ( $url -ne $hapikey )


        #-----------------------------------------------
        # FULL ARCHIVED CONTACTS
        #-----------------------------------------------

        if ( $settings.loadArchivedRecords ) {

            $object = "crm"
            $apiVersion = "v3"
            $limit = $settings.pageLimitGet
            $archived = "true"
            $url = "$( $settings.base )$( $object )/$( $apiVersion )/objects/contacts?limit=$( $limit )&archived=$( $archived )&properties=$( $properties.name -join "," )$( $hapikey )"

            #$archivedContacts = @()
            Do {
    
                # Get all contacts
                $archivedContactsResult = Invoke-RestMethod -Method Get -Uri $url -Verbose
    
                # Add contacts to array
                $contacts += $archivedContactsResult.results

                Write-Log -message "Loaded $( $contacts.count ) 'contacts' (currently archived) in total"

                # Load next url
                $url = "$( $archivedContactsResult.paging.next.link )$( $hapikey )"

            } while ( $url -ne $hapikey )

        }

    }

    "DELTA" {


        #-----------------------------------------------
        # DELTA ACTIVE CONTACTS
        #-----------------------------------------------

        $object = "crm"
        $apiVersion = "v3"
        $limit = $settings.pageLimitGet
        $url = "$( $settings.base )$( $object )/$( $apiVersion )/objects/contacts/search?$( $hapikey )"

        # Create body to ask for contacts
        $body = [ordered]@{
            "filterGroups" = @(
                @{
                    "filters" = @(
                        @{
                            "propertyName"="lastmodifieddate"
                            "operator"="GTE"
                            "value"= $lastTimestamp
                         }
                    )
                }
            )
            sorts = @("lastmodifieddate")
            #query = ""
            properties = $properties.name #@("firstname", "lastname", "email")
            limit = $limit
            after = 0
        } 
        
        # Query the result in pages
        $contacts = @()
        Do {
    
            # Get all contacts results
            $bodyJson = $body | ConvertTo-Json -Depth 8
            $contactsResult = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body $bodyJson -Verbose
    
            # Add contacts to array
            $contacts += $contactsResult.results

            Write-Log -message "Loaded $( $contacts.count ) 'contacts' in total"

            # prepare next batch -> with search the "paging" does not contain IDs, it contains only integers the index of the search result
            $body.after = $contactsResult.paging.next.after

        } while ( $contactsResult.paging ) # only while the paging object is existing

    }

}

Write-Log -message "Done with downloading $( $contacts.count ) 'contacts' in total"


################################################
#
# EXPORT DATA INTO CSV
#
################################################

Write-Log -message "Exporting the data into CSV and creating a folder with the id $( $processId )"

# Create folder
New-Item -Path $settings.exportDir -ItemType Directory

$objectPrefix = "contacts__"

if ($contacts.Count -gt 0) {

    # Export properties table
    $properties | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * | Export-Csv -Path "$( $settings.exportDir )$( $objectPrefix )properties.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

    # Export data
    $contacts | Select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, id, createdAt, updatedAt, archived -ExpandProperty properties | Out-Null # Expand contacts first
    $propertiesGroups | ForEach-Object {
        $currentGroup = $_.groupName -replace "-","" # replace dashes in group names if present, because sqlite does not like them as table names
        $currentProperties = $properties | where { $_.groupName -eq $currentGroup } | Select name
        $colsForExport = @("ExtractTimestamp","id", "createdAt", "updatedAt", "archived") + $currentProperties.name
        $contacts.properties | select $colsForExport | Export-Csv -Path "$( $settings.exportDir )$( $objectPrefix )$( $currentGroup ).csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8
    }

}

Write-Log -message "Exported $( (Get-ChildItem -Path $settings.exportDir).Count ) files with the id $( $processId )"


################################################
#
# SAVE LAST LOADED TIMESTAMP
#
################################################

$lastSession = @{
    lastTimestamp = $currentTimestamp
    lastTimeStampHuman = Get-Date $currentTimestampDateTime -Format "yyyyMMdd_HHmmss"
}

# create json object
$lastSessionJson = $lastSession | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$lastSessionJson

# save settings to file
$lastSessionJson | Set-Content -path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8

Write-Log -message "Saved the current timestamp '$( $currentTimestamp )' for the next run in '$( $scriptPath )\$( $lastSessionFilename )'"

# Exit if there is no new result
if ( $contacts.count -eq 0 ) {
    Write-Log -message "No new data -> exit"
    Exit 0
}

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
        Send-MailMessage -SmtpServer $settings.mailSettings.smtpServer -From $settings.mailSettings.from -To $settings.mailSettings.to -Port $settings.mailSettings.port -UseSsl -Credential $smtpcred `
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

