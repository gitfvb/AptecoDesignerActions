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
    Split-Path -Path $settings.sqliteDb -Parent
    Split-Path -Path $settings.buildNowFile -Parent
    Split-Path -Path $settings.sessionFile -Parent
    Split-Path -Path $settings.hapiKeyFile -Parent
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

$contentType = "application/json" #"application/json; charset=utf-8"


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
$objectTypesToLoad = ( $settings.objectTypesToLoad | Get-Member -MemberType NoteProperty ).Name  #$settings.objectTypesToLoad

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
            $objectSettings = $settings.objectTypesToLoad.$objectType

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
                    if ( $settings.loadArchivedRecords -and ( $loadArchivedInProgress -eq $false ) -and $objectType.loadArchived ) {
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

        # Load engagements from older v1 API 
        If ( $settings.loadEngagements ) {

            $offset = 0
            $pagesize = $settings.pageLimitGet
            $url = "$( $settings.base )engagements/v1/engagements/paged?limit=$( $pagesize )$( $hapikey )"
            $obj = [System.Collections.ArrayList]@()
            Do {
                $params = [hashtable]@{
                    "Uri" = "$( $url )&offset=$( $offset )"
                    "Method" = "GET"
                    "Verbose" = $true
                }
                $objRes = Invoke-RestMethod @params
                $obj.AddRange( $objRes.results )
                $offset = $objRes.offset
            } while ( $objRes.hasMore )

            Write-Log -message "Loaded $( $obj.count ) 'engagements' in summary"

            # Add objects to a pscustom
            $customFormat = @(
                @{name="id";expression={ $_.engagement.id }}
                @{name="properties";expression={ $_ }}
                @{name="createdAt";expression={ ( Get-DateTimeFromUnixtime -unixtime $_.engagement.createdAt -inMilliseconds ).toString("yyyy-MM-ddThh:mm:ss.fffZ") }}
                @{name="updatedAt";expression={ ( Get-DateTimeFromUnixtime -unixtime $_.engagement.lastUpdated -inMilliseconds ).toString("yyyy-MM-ddThh:mm:ss.fffZ") }}
                @{name="archived";expression={ $false }}

            )
            $objects | Add-Member -MemberType NoteProperty -Name "engagements" -Value ( $obj | select $customFormat )           

        }

    }

    "DELTA" {

        #-----------------------------------------------
        # DELTA ACTIVE OBJECTS
        #-----------------------------------------------
        
        $objects = [PSCustomObject]@{}
        $objectTypesToLoad | ForEach {
            
            $objectType = $_
            $objectSettings = $settings.objectTypesToLoad.$objectType

            $limit = $settings.pageLimitGet
            $props = $properties.$objectType
            $lastmodifiedProperty = $objectSettings.updatedField

            # Create body to ask for objects
            $body = [ordered]@{
                "filterGroups" = @(
                    @{
                        "filters" = @(
                            @{
                                "propertyName"=$lastmodifiedProperty
                                "operator"="GTE"
                                "value"= $lastTimestamp
                            }
                        )
                    }
                )
                sorts = @($lastmodifiedProperty)
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
                try {

                    $objRes = [PSCustomObject]@{}
                    #$bodyJson
                    $objRes = Invoke-RestMethod -Method Post -Uri $url -ContentType $contentType -Body $bodyJson -Verbose

                    # Add objects to array
                    $obj.AddRange( $objRes.results )

                } catch {
            
                    $e = ParseErrorForResponseBody($_)
                    Write-Log -message ( $e | ConvertTo-Json -Depth 20 -Compress ) -severity ([LogSeverity]::ERROR)
                    throw $_.exception
            
                    #Write-Host $_ -fore green
                }            
        
                Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in total"
                
                # prepare next batch -> with search the "paging" does not contain IDs, it contains only integers the index of the search result
                $body.after = $objRes.paging.next.after

            } while ( $objRes.paging ) # only while the paging object is existing

            Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' in summary"

            # Add objects to a pscustom
            $objects | Add-Member -MemberType NoteProperty -Name $objectType -Value $obj

        }

        # Load engagements from older v1 API 
        If ( $settings.loadEngagements ) {

            $offset = 0
            $pagesize = $settings.pageLimitGet
            $unixtime = $lastSession.lastTimestamp #- 604800000 # load the last 7 days for testing
            $url = "$( $settings.base )engagements/v1/engagements/recent/modified?count=$( $pagesize )$( $hapikey )&since=$( $unixtime )"
            $obj = [System.Collections.ArrayList]@()
            Do {
                $params = [hashtable]@{
                    "Uri" = "$( $url )&offset=$( $offset )"
                    "Method" = "GET"
                    "Verbose" = $true
                }
                $objRes = Invoke-RestMethod @params
                $obj.AddRange( $objRes.results )
                $offset += $pagesize
            } while ( $objRes.hasMore )

            Write-Log -message "Loaded $( $obj.count ) 'engagements' in summary"

            # Add objects to a pscustom
            $customFormat = @(
                @{name="id";expression={ $_.engagement.id }}
                @{name="properties";expression={ $_ }}
                @{name="createdAt";expression={ ( Get-DateTimeFromUnixtime -unixtime $_.engagement.createdAt -inMilliseconds ).toString("yyyy-MM-ddThh:mm:ss.fffZ") }}
                @{name="updatedAt";expression={ ( Get-DateTimeFromUnixtime -unixtime $_.engagement.lastUpdated -inMilliseconds ).toString("yyyy-MM-ddThh:mm:ss.fffZ") }}
                @{name="archived";expression={ $false }}

            )
            $objects | Add-Member -MemberType NoteProperty -Name "engagements" -Value ( $obj | select $customFormat )           

        }

        # Load all active records to identify deleted ones
        # TODO [ ] do this maybe once a day OR every n times OR with another extract method
        $objectIDs = [System.Collections.ArrayList]@{}
        $objectTypesToLoad | ForEach {
            
            $objectType = $_
            $object = "crm"
            $apiVersion = "v3"
            $limit = $settings.pageLimitGet
            $archived = "false"
            $props = [array]@()
            $type = "objects"
            $url = "$( $settings.base )$( $object )/$( $apiVersion )/$( $type )/$( $objectType )?limit=$( $limit )&archived=$( $archived )&properties=$( $props.name -join "," )$( $hapikey )"
            
            $finish = $false
            $obj = [System.Collections.ArrayList]@()
            Do {
        
                # Get all objects in page
                $objRes = Invoke-RestMethod -Method Get -Uri $url -Verbose
        
                # Add objects to array
                $obj.AddRange( $objRes.results.id )
    
                Write-Log -message "Loaded $( $obj.count ) '$( $objectType )' IDs in total"
                    
                # Check if finished
                if ( $objRes.paging ) {
                    
                    # Load next url
                    $url = "$( $objRes.paging.next.link )$( $hapikey )"

                } else {
                 
                    $finish = $true

                }

            } until ( $finish )

            $objectIDs.AddRange($obj)

        }

        Write-Log -message "Loaded $( $objectIDs.count ) active IDs in summary"

        # Add objects to a pscustom
        $activeIDs = [System.Collections.ArrayList]@(
            [PSCustomObject]@{
                "id" = 0
                "properties" = $objectIDs #| ConvertTo-Json -Compress
                "createdAt" = $timestamp.toString("yyyy-MM-ddThh:mm:ss.fffZ")
                "updatedAt" = $timestamp.toString("yyyy-MM-ddThh:mm:ss.fffZ")
                "archived" = $false
        })
        $objects | Add-Member -MemberType NoteProperty -Name "active_ids" -Value ( $activeIDs )

    }

}


#-----------------------------------------------
# COUNT THE ITEMS TO SEE IF WE SHOULD PROCEED
#-----------------------------------------------

If ( $settings.loadEngagements ) {
    $objectTypesToLoad += "engagements"
}

$objectTypesToLoad += "active_ids"

$itemsTotal = 0
$objectTypesToLoad | ForEach {

    $objectType = $_

    $itemsTotal += $objects.$objectType.count

}

If ( $itemsTotal -gt 0 ) {
    Write-Log -message "Counted $( $itemsTotal ) items in total -> Proceed loading into the database"
} else {
    Write-Log -message "No updated or new items -> Closing the process now"
    exit 0
}


################################################
#
# BACKUP SQLITE FIRST
#
################################################

Write-Log -message "Setting for creating backups $( $settings.backupSqlite )"

if ( $settings.backupSqlite ) {  

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

        if ( Test-Path -Path $source ) {
            Write-Log -message "Creating backup of $( $source )"    

            Copy-Item -Path $source -Destination $destinationWithTimestamp -Force -Recurse

        } else {

            Write-Log -message "File $( $source ) does not exist -> no backup"

        }

    }

}


################################################
#
# LOAD DATA INTO SQLITE
#
################################################

Write-Log -message "Loading data directly into sqlite"


#-----------------------------------------------
# ESTABLISHING CONNECTION TO SQLITE
#-----------------------------------------------

# Load assemblies for sqlite
$assemblyFileSqlite = $libExecutables.Where({$_.name -eq "System.Data.SQLite.dll"})
[Reflection.Assembly]::LoadFile($assemblyFileSqlite.FullName)

# Create a new connection to a database (in-memory of file)
# If the database does not exist, it will be created automatically
$connection = [System.Data.SQLite.SQLiteConnection]::new()
#$connection.ConnectionString = "Data Source=:memory:;Version=3;New=True;"
$connection.ConnectionString = "Data Source=$( $settings.sqliteDb );Version=3;New=True;" # TODO [ ] put this into settings
$connection.Open()

# Load more extensions for sqlite, e.g. the Interop which includes json1
#$connection.EnableExtensions($true)
#$assemblyFileInterop = Get-Item -Path ".\sqlite-netFx46-binary-x64-2015-1.0.113.0\SQLite.Interop.dll"
#$connection.LoadExtension($assemblyFileInterop.FullName, "sqlite3_json_init");

# Create a new command which can be reused
$command = [System.Data.SQLite.SQLiteCommand]::new($connection)


#-----------------------------------------------
# CREATE TABLES FOR STORING HUBSPOT CRM DATA
#-----------------------------------------------

<#
# Drop a table, if exists
$command.CommandText = "DROP TABLE IF EXISTS jobitems";
[void]$command.ExecuteNonQuery();
#>

# Create a new table for object items, if it is not existing
$command.CommandText = @"
CREATE TABLE IF NOT EXISTS hubspot_items (
     id TEXT
    ,object TEXT 
    ,ExtractTimestamp TEXT
    ,createdAt TEXT
    ,updatedAt TEXT
    ,archived TEXT
    ,properties TEXT
)
"@
[void]$command.ExecuteNonQuery();

# Create a new table for properties, if it is not existing
$command.CommandText = @"
CREATE TABLE IF NOT EXISTS hubspot_properties (
     id TEXT
    ,object TEXT 
    ,ExtractTimestamp TEXT
    ,createdAt TEXT
    ,updatedAt TEXT
    ,property TEXT
)
"@
[void]$command.ExecuteNonQuery();


#-----------------------------------------------
# PREPARE QUERIES FOR INSERTING DATA
#-----------------------------------------------

# Prepare command for inserting properties
$insertStatementProperties = @"
INSERT INTO
    hubspot_properties(id, object, ExtractTimestamp, createdAt, updatedAt, property)
VALUES
    (@id, @object, @ExtractTimestamp, @createdAt, @updatedAt, @property)
"@

# Prepare command for inserting rows
$insertStatementItems = @"
INSERT INTO
    hubspot_items(id, object, ExtractTimestamp, createdAt, updatedAt, archived, properties)
VALUES
    (@id, @object, @ExtractTimestamp, @createdAt, @updatedAt, @archived, @properties)
"@


#-----------------------------------------------
# LOADING DATA FROM HUBSPOT INTO SQLITE
#-----------------------------------------------

$insertedProperties = 0
$insertedRows = 0
$t = Measure-Command {

    $objectTypesToLoad | ForEach {

        $objectType = $_


        #-----------------------------------------------
        # LOADING PROPERTIES
        #-----------------------------------------------

        $sqliteTransaction = $connection.BeginTransaction()
        $properties.$objectType | ForEach {

            $property = $_

            $command.CommandText = $insertStatementProperties

            [void]$command.Parameters.AddWithValue("@object", $objectType)        
            [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $currentTimestamp)

            [void]$command.Parameters.AddWithValue("@id", $property.name)
            [void]$command.Parameters.AddWithValue("@createdAt", $property.createdAt)
            [void]$command.Parameters.AddWithValue("@updatedAt", $property.updatedAt)
            [void]$command.Parameters.AddWithValue("@property", ( $property | convertto-json -Compress -Depth 99 ))

            [void]$command.Prepare()

            $insertedProperties += $command.ExecuteNonQuery()

        }
        $sqliteTransaction.Commit()


        #-----------------------------------------------
        # LOADING ITEMS
        #-----------------------------------------------

        $sqliteTransaction = $connection.BeginTransaction()
        $objects.$objectType | ForEach {

            $row = $_
            
            $command.CommandText = $insertStatementItems

            [void]$command.Parameters.AddWithValue("@object", $objectType)        
            [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $currentTimestamp)

            [void]$command.Parameters.AddWithValue("@id", $row.id)
            [void]$command.Parameters.AddWithValue("@createdAt", $row.createdAt)
            [void]$command.Parameters.AddWithValue("@updatedAt", $row.updatedAt)
            [void]$command.Parameters.AddWithValue("@archived", $row.archived)
            [void]$command.Parameters.AddWithValue("@properties", ( $row.properties | convertto-json -Compress -Depth 20 ))

            [void]$command.Prepare()

            $insertedRows += $command.ExecuteNonQuery()

        }
        $sqliteTransaction.Commit()


    }

}


#-----------------------------------------------
# CLOSING CONNECTION
#-----------------------------------------------

$command.Dispose()
$connection.Dispose()


#-----------------------------------------------
# LOG RESULTS
#-----------------------------------------------

Write-Log -message "Inserted $( $insertedProperties ) properties in total"
Write-Log -message "Inserted $( $insertedRows ) items in total"
Write-Log -message "Needed $( $t.TotalSeconds ) seconds for inserting data"


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
$lastSessionJson | Set-Content -path "$( $settings.sessionFile )" -Encoding UTF8

Write-Log -message "Saved the current timestamp '$( $currentTimestamp )' for the next run in '$( $scriptPath )\$( $lastSessionFilename )'"


$objectTypesToLoad | ForEach {

    $objectType = $_

    # Exit if there is no new result
    if ( $proceed -eq $false ) {
        
        Write-Log -message "No new data -> exit"
        
        Exit 0

    }

}

exit 0





















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

Write-Log -message "Exporting the data into CSV and creating a folder with the id $( $processId )"

$proceed = $false
$objectTypesToLoad | ForEach {

    $objectType = $_
    $objectPrefix = "$( $objectType )__"

    if ( $objects.$objectType.count -gt 0 ) {

        Write-Log -message "Exporting the data of object type $( $objectType )"

        # Set proceed to true
        $proceed = $true

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
# LOAD CSV INTO SQLITE (EXTEND TABLES AND INFORM OF NEW COLUMNS)
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
# LOAD CSV INTO SQLITE (LOAD FILES AS IS -> TRANSFORM THE DATA TO KEY/VALUE BEFORE)
#
################################################

# TODO [ ] make use of transactions for sqlite to get it safe

Write-Log -message "Import data into sqlite '$( $settings.sqliteDb )'"    
$newDatabase = Test-Path -Path $settings.sqliteDb

# Settings for sqlite
$sqliteExe = $libExecutables.Where({$_.name -eq "sqlite3.exe"}).FullName
$processIdSqliteSafe = "temp__$( $processId.Guid.Replace('-','') )" # sqlite table names are not allowed to contain dashes or begin with numbers
$filesToImport = Get-ChildItem -Path $exportFolder -Include $settings.filterForSqliteImport -Recurse

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

    # Check columns if database is already existing
    #if ( !$newDatabase ) {

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
    #}

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
    Write-Log -message "Creating file '$( $settings.buildNowFile )'"
    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $settings.buildNowFile -Encoding utf8 -Force
}


################################################
#
# STARTING BUILD
#
################################################

exit 0

& "C:\Program Files\Apteco\FastStats Designer\DesignerConsole.exe" "D:\Apteco\Build\Hubspot\designs\hubspot.xml" /load
