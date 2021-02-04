################################################
#
# INPUT
#
################################################

#Param(
#    $scriptPath
#)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        scriptPath = "C:\Users\Florian\Documents\GitHub\AptecoDesignerActions\preload\HubspotExtract"
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
$modulename = "hubspot_extract"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

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

# Backup settings
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
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$foldersToCheck = @(
    $settings.exportDir
    $settings.backupDir
)

$foldersToCheck | ForEach {
    $folder = $_
    if ( !(Test-Path -Path $folder) ) {
        Write-Log -message "Folder $( $folder ) does not exist. Creating the it now!"
        New-Item -Path "$( $folder )" -ItemType Directory
    }
}


#-----------------------------------------------
# PREPARE TOKEN
#-----------------------------------------------

if ( $settings.saveHapiKeyAsFile ) {
    $hapikeyEncrypted = Get-Content $settings.hapiKeyFile -Encoding UTF8 # TODO [ ] use the path here from settings
} else {
    $hapikeyEncrypted = $settings.login.hapikey
}

$hapikey = "&hapikey=$( Get-SecureToPlaintext -String $hapikeyEncrypted )"


#-----------------------------------------------
# MAIL SETTINGS
#-----------------------------------------------

$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext -String $settings.mail.password ) -AsPlainText -Force
$smtpcred = New-Object PSCredential $settings.mail.from,$stringSecure


#-----------------------------------------------
# HEADERS
#-----------------------------------------------

$contentType = "application/json"


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
# LOAD OBJECTS PROPERTIES
#
################################################

# https://developers.hubspot.com/docs/api/crm/properties

# TODO [ ] put this one into the settings
$objectTypesToLoad = $settings.objectTypesToLoad

$properties = [PSCustomObject]@{}
$objectTypesToLoad | ForEach {

    $objectType = $_
    $object = "crm"
    $apiVersion = "v3"
    $archived = "false"
    $type = "properties"
    $url = "$( $settings.base )$( $object )/$( $apiVersion )/$( $type )/$( $objectType )?archived=$( $archived )$( $hapikey )"
    $res = Invoke-RestMethod -Method Get -Uri $url

    # Find out different groups of properties
    #$propertiesGroups = $res | select -Unique groupName

    # Create custom object to hold all properties
    $properties | Add-Member -MemberType NoteProperty -Name $objectType -Value $res.results

    Write-Log -message "Loaded $( $res.results.count ) '$( $objectType )' properties" # and $( $propertiesGroups.count ) property groups"

}


################################################
#
# PREPARE LOADING OBJECTS
#
################################################


#-----------------------------------------------
# LOAD LAST SESSION AND DECIDE ON EXTRACT METHOD
#-----------------------------------------------

If ( Check-Path -Path "$( $settings.sessionFile )" ) {
    $lastSession = Get-Content -Path "$( $settings.sessionFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
    $lastTimestamp = $lastSession.lastTimestamp
    $extractMethod = "DELTA" # FULL|DELTA

    Write-Log -message "Last timestamp: $( $lastTimestamp )"
    Write-Log -message "Pretty timestamp: $( Get-Date ( Get-DateTimeFromUnixtime -unixtime $lastTimestamp -inMilliseconds -convertToLocalTimezone ) -Format "yyyyMMdd_HHmmss" )"

} else {
    $extractMethod = "FULL" # FULL|DELTA
}

Write-Log -message "Chosen extract method: $( $extractMethod )"


#-----------------------------------------------
# LOG LAST TIMESTAMPS
#-----------------------------------------------

#$lastTimestamp = Get-Unixtime -timestamp ( (Get-Date).AddMonths(-1) ) -inMilliseconds
[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp
$currentTimestampDateTime = Get-DateTimeFromUnixtime -unixtime $currentTimestamp -inMilliseconds -convertToLocalTimezone
Write-Log -message "Current timestamp: $( $currentTimestamp )"


################################################
#
# LOAD OBJECTS
#
################################################


Switch ( $extractMethod ) {
    
    "FULL" {

        #-----------------------------------------------
        # FULL ACTIVE + OPTIONALLY ARCHIVED OBJECTS
        #-----------------------------------------------

        $objects = [PSCustomObject]@{}
        $objectTypesToLoad | ForEach {
            
            $objectType = $_
            $object = "crm"
            $apiVersion = "v3"
            $limit = $settings.pageLimitGet
            $archived = "false"
            $props = $properties.$objectType
            $type = "objects"
            $url = "$( $settings.base )$( $object )/$( $apiVersion )/$( $type )/$( $objectType )?limit=$( $limit )&archived=$( $archived )&properties=$( $props.name -join "," )$( $hapikey )"
            
            $loadArchivedInProgress = $false
            $finish = $false
            $obj = [System.Collections.ArrayList]@()
            Do {
        
                # Get all objects in page
                $objRes = Invoke-RestMethod -Method Get -Uri $url -Verbose
        
                # Add objects to array
                $obj.AddRange( $objRes.results )
    
                Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in total"
                    
                # Check if finished
                if ( $objRes.paging ) {
                    
                    # Load next url
                    $url = "$( $objRes.paging.next.link )$( $hapikey )"

                } else {

                    # Check if archived records should be loaded, too
                    if ( $settings.loadArchivedRecords -and $loadArchivedInProgress -eq $false ) {
                        $loadArchivedInProgress = $true
                        $archived = "true"
                        $url = "$( $settings.base )$( $object )/$( $apiVersion )/$( $type )/$( $objectType )?limit=$( $limit )&archived=$( $archived )&properties=$( $props.name -join "," )$( $hapikey )"
                        Write-Log -message "Loading archived records now, too"
                    } else {
                        $finish = $true
                    }

                }

            } until ( $finish )    

            Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in summary"

            # Add objects to a pscustom
            $objects | Add-Member -MemberType NoteProperty -Name $objectType -Value $obj

        }

    }

    "DELTA" {

        #-----------------------------------------------
        # DELTA ACTIVE OBJECTS
        #-----------------------------------------------
        
        $objects = [PSCustomObject]@{}
        $objectTypesToLoad | ForEach {
            
            $objectType = $_

            $limit = $settings.pageLimitGet
            $props = $properties.$objectType

            # Create body to ask for objects
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
                properties = $props.name #@("firstname", "lastname", "email")
                limit = $limit
                after = 0
            }


            $object = "crm"
            $apiVersion = "v3"
            $type = "objects"
            $url = "$( $settings.base )$( $object )/$( $apiVersion )/$( $type )/$( $objectType )/search?$( $hapikey )"

            # Load the data
            $obj = [System.Collections.ArrayList]@()
            Do {
        
                # Get all objects in page
                $bodyJson = $body | ConvertTo-Json -Depth 8
                $objRes = Invoke-RestMethod -Method Post -Uri $url -ContentType $contentType -Body $bodyJson -Verbose
        
                # Add objects to array
                $obj.AddRange( $objRes.results )
    
                Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in total"
                
                # prepare next batch -> with search the "paging" does not contain IDs, it contains only integers the index of the search result
                $body.after = $objRes.paging.next.after

            } while ( $objRes.paging ) # only while the paging object is existing

            Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in summary"

            # Add objects to a pscustom
            $objects | Add-Member -MemberType NoteProperty -Name $objectType -Value $obj

        }


    }

}


################################################
#
# EXPORT DATA INTO CSV
#
################################################

#-----------------------------------------------
# CREATE EXPORT FOLDER
#-----------------------------------------------

$exportFolder = "$( $settings.exportDir )\$( $currentTimestamp )_$( $processId )"
Write-Log -message "Folder $( $exportFolder ) does not exist. Creating the folder now!"
New-Item -Path "$( $exportFolder )" -ItemType Directory

#-----------------------------------------------
# EXPORT FILES
#-----------------------------------------------

$objectTypesToLoad | ForEach {

    $objectType = $_
    $objectPrefix = "$( $objectType )__"

    if ( $objects.$objectType.count -gt 0 ) {

        Write-Log -message "Exporting the data into CSV and creating a folder with the id $( $processId )"

        # Export properties table
        $properties.$objectType | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
        | Export-Csv -Path "$( $exportFolder )\$( $objectPrefix )properties.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

        # Export properties options
        $properties.$objectType | select name -ExpandProperty options `
        | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
        | Export-Csv -Path "$( $exportFolder )\$( $objectPrefix )properties__options.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

        # Export object type meta data like id, updated etc.
        $objects.$objectType | Select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * -ExcludeProperty properties `
        | Export-Csv -Path "$( $exportFolder )\$( $objectPrefix )meta.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

        # Export properties of objects
        $objects.$objectType | select id -ExpandProperty properties `
        | Format-KeyValue -idPropertyName id -removeEmptyValues `
        | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
        | Export-Csv -Path "$( $exportFolder )\$( $objectPrefix )properties__values.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

    }

}



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


exit 0


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
# LOAD CSV INTO SQLITE (CLEVERREACH)
#
################################################
<#
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

#>

################################################
#
# CREATE SUCCESS FILE
#
################################################

if ( $settings.createBuildNow ) {
    Write-Log -message "Creating file '$( $settings.buildNowFile )'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.buildNowFile -Encoding utf8 -Force
}


################################################
#
# STARTING BUILD
#
################################################


& "C:\Program Files\Apteco\FastStats Designer\DesignerConsole.exe" "D:\Apteco\Build\Hubspot\designs\hubspot.xml" /load
