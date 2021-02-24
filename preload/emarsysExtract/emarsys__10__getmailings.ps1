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
	    Password= "def"
        scriptPath = "C:\Users\Florian\Documents\GitHub\AptecoDesignerActions\preload\emarsysExtract"
	    abc= "def"
	    Username= "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://dev.emarsys.com/v2/first-steps/1-prerequisites

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
$moduleName = "EMARSYSMAILINGS"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


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

# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}
<#
# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>


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
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
}


################################################
#
# HANDLING EMARSYS
#
################################################

#$settingsLoad = Invoke-RestMethod @params

$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.secret ) -AsPlainText -Force
$cred = [pscredential]::new( $settings.login.username, $stringSecure )

# Read static attribute
[Emarsys]::allowNewFieldCreation

# Create emarsys object
$emarsys = [Emarsys]::new($cred,$settings.base)

[uint64]$currentTimestamp = Get-Unixtime -inMilliseconds -timestamp $timestamp


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

# Read settings
$emarsys.getSettings()


#-----------------------------------------------
# SETUP THE OUTPUT FOLDER
#-----------------------------------------------

# Create temporary directory
$exportTimestamp = $currentTimestamp.ToString("yyyyMMdd_HHmmss")
$exportFolder = "$( $settings.download.folder )\$( $exportTimestamp )_$( $processId.Guid )\"
New-Item -Path $exportFolder -ItemType Directory


#-----------------------------------------------
# EXPORT WITH ALL FIELDS IN BACKGROUND
#-----------------------------------------------

$loadFolder = "$( $exportFolder )\1_load"
New-Item -Path $loadFolder -ItemType Directory

$lists = $emarsys.getLists()
$selectedlist = ( $lists | Select *,  @{name="count";expression={ $_.count() }} -exclude raw ) | Out-GridView -PassThru
#$list = $lists | where { $selectedlist.id -contains $_.id }

#$fields = $emarsys.getFields($false) | Out-GridView -PassThru | Select -first 20
$exports = [System.Collections.ArrayList]@()
$lists | where { $selectedlist.id -contains $_.id } | ForEach {
    $list = $_
    $exports.AddRange( $emarsys.downloadContactList($list,$loadFolder) )
}

$exports.autoUpdate($true) # This will automatically check the export job and the $true will automatically download it afterwards

# Wait until all Jobs are finished and all downloaded
Do {
    Start-Sleep -seconds 1
    Write-Host "Done $( ( $exports | where { $_.status -eq "done" } ).count ) of $( $exports.count )" #-NoNewline
} until ( ( $exports | where { $_.status -eq "done" } ).count -eq $exports.count )

#$exports.downloadResult()

# TODO [ ] Do the next steps with a filewatcher in parallel rather than sequential
# TODO [ ] Next steps: Split, Transform, import to sqlite


################################################
#
# FILE HANDLING
#
################################################


#-----------------------------------------------
# SPLIT THE DOWNLOADED FILES
#-----------------------------------------------

$splitFolder = "$( $exportFolder )\2_split"
New-Item -Path $splitFolder -ItemType Directory

# Remember the current location and change to the export dir
$currentLocation = Get-Location
Set-Location $loadFolder

$splitJobs = [System.Collections.ArrayList]@()
Get-ChildItem -Path $loadFolder | ForEach {

    # Split file in parts
    $t = Measure-Command {
        $fileItem = $_
        $splitParams = @{
            inputPath = $fileItem.FullName
            header = $true
            writeHeader = $true
            inputDelimiter = ";"
            outputDelimiter = "`t"
            #outputColumns = $fields
            writeCount = 500 #$settings.rowsPerUpload # TODO [ ] change this back for productive use
            outputDoubleQuotes = $true
        }
        $exportId = Split-File @splitParams
        $splitJobs.Add($exportId)

    }

    Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"

    # Move files to next step and remove folders
    Move-Item -Path "$( $exportId )\*" -Destination $splitFolder
    Remove-Item -Path $exportId

}

# Set the location back
Set-Location $currentLocation



# TODO [ ] built in backup from hubspot




#-----------------------------------------------
# TRANSFORM FILES
#-----------------------------------------------

$transformFolder = "$( $exportFolder )\3_transform"
New-Item -Path $transformFolder -ItemType Directory

$filesToTransform = Get-ChildItem -Path $splitFolder

$i = 1
$filesToTransform | ForEach {

    $f = $_

    $listId = ( $f.Name -split "_" )[1]
    $csvData = Import-Csv -Path $f.FullName -Delimiter "`t" -Encoding UTF8

    Write-Log -message "Transforming $( $f.name )"
    "Doing $( $i ) of $( $filesToTransform.count )"

    # TODO [ ] check if primary key is still user_id
    $csvData `
    | select *, @{name="listId";expression={ $listId }} `
    | Format-KeyValue -idPropertyName "user_id","listId" -removeEmptyValues `
    | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
    | Export-Csv -Path "$( $transformFolder )\$( $f.Name )" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

    $i++

}


#-----------------------------------------------
# ADD META INFORMATION
#-----------------------------------------------

$metaFolder = "$( $exportFolder )\0_meta"
New-Item -Path $metaFolder -ItemType Directory

# Load lists
$emaLists = $emarsys.getLists()
$emaLists | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
| Export-Csv -Path "$( $metaFolder )\lists.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8

# Load campaigns
$emaCampaigns = $emarsys.getEmailCampaigns()
$emaCampaigns | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
| Export-Csv -Path "$( $metaFolder )\campaigns.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8


# Load fields with details
$emaFields = $emarsys.getFields($true)
$emaFields | select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
| Export-Csv -Path "$( $metaFolder )\fields.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8


# Fields choices
$emaFields | Select @{name="FieldID";expression={ $_.id }}  -ExpandProperty choices `
| select @{name="ExtractTimestamp";expression={ $currentTimestamp }}, * `
| Export-Csv -Path "$( $metaFolder )\fields_choices.csv" -NoTypeInformation -Delimiter "`t" -Encoding UTF8


################################################
#
# LOAD CSV INTO SQLITE (LOAD FILES AS IS -> TRANSFORM THE DATA TO KEY/VALUE BEFORE)
#
################################################

# TODO [ ] make use of transactions for sqlite to get it safe
# TODO [ ] remove this one and put into settings
$settings | Add-Member -MemberType NoteProperty -Name "sqliteDb" -Value "C:\Users\Florian\Documents\GitHub\AptecoDesignerActions\preload\emarsysExtract\downloads\db.sqlite"
$settings.sqliteDb = "C:\Users\Florian\Documents\GitHub\AptecoDesignerActions\preload\emarsysExtract\downloads\db.sqlite"
Write-Log -message "Import data into sqlite '$( $settings.sqliteDb )'"    
$newDatabase = Test-Path -Path $settings.sqliteDb

# Settings for sqlite
$sqliteExe = $libExecutables.Where({$_.name -eq "sqlite3.exe"}).FullName
$processIdSqliteSafe = "temp__$( $processId.Guid.Replace('-','') )" # sqlite table names are not allowed to contain dashes or begin with numbers

# Create database if not existing
# In sqlite the database gets automatically created if it does not exist

#-----------------------------------------------
# IMPORT DATA
#-----------------------------------------------

Get-ChildItem -Path $transformFolder -Recurse | ForEach {

    # Prepare
    $f = $_
    $listId = ( $f.Name -split "_" )[1]
    $part = $f.Extension -replace "\."
    $tempName = "$( $part )$( $listId )"
    $finalDestination = "data"
    
    # Import into temp table
    $tempImport = ImportCsv-ToSqlite -sourceCsv $f.FullName -destinationTable $tempName -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
    $columnsTemp = Read-Sqlite -query "PRAGMA table_info($( $tempName ))" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 

    # Create persistent tables if not existing
    $tableCreationStatement  = ( Read-Sqlite -query ".schema $( $tempName )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false ) -replace $tempName, "IF NOT EXISTS $( $finalDestination )"    

    if ( $tableCreationStatement ) {

        $tableCreation = Read-Sqlite -query $tableCreationStatement -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe -convertCsv $false

        # Import the files temporarily with process id
        $columnsString = $columnsTemp.Name -join ", "
        Read-Sqlite -query "INSERT INTO $( $finalDestination ) ( $( $columnsString ) ) SELECT $( $columnsString ) FROM $( $tempName )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe    

        # Drop temp table
        Read-Sqlite -query "Drop table $( $tempName )" -sqliteDb $settings.sqliteDb -sqliteExe $sqliteExe 
        Write-Log -message "Dropping temporary table '$( $tempName )'"

    }

}



#-----------------------------------------------
# IMPORT THE METAINFORMATION
#-----------------------------------------------

# Choose files to import
$filesToImport = Get-ChildItem -Path $metaFolder -Recurse #-Include $settings.filterForSqliteImport # $transformFolder

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

































#-----------------------------------------------
# EXPORT WITH SELECTED FIELDS
#-----------------------------------------------

$lists = $emarsys.getLists()
$selectedlist = ( $lists | Select *,  @{name="count";expression={ $_.count() }} -exclude raw ) | Out-GridView -PassThru
#$list = $lists | where { $selectedlist.id -contains $_.id }

$fields = $emarsys.getFields($false) | Out-GridView -PassThru | Select -first 20
$exports = [System.Collections.ArrayList]@()
$lists | where { $selectedlist.id -contains $_.id } | ForEach {
    $list = $_
    $exports.Add( $emarsys.downloadContactList($list,$fields,".") )
}

$exports.autoUpdate()

# Wait until all Jobs are finished
Do {
    Start-Sleep -seconds 1
    Write-Host "Done $( ( $exports | where { $_.status -eq "done" } ) ).count of $( $exports.count )"
} until ( ( $exports | where { $_.status -eq "done" } ).count -eq $exports.count )

$exports.downloadResult()

exit 0


do {
    Start-Sleep -seconds 10
    $export.updateStatus()
    # TODO [ ] download and process the data when already done
} until ($export.status -eq "done")

$export.downloadResult(".")


<#
use split files for bigger files
transform object
import into sqlite
#>

exit 0


#-----------------------------------------------
# FIELDS
#-----------------------------------------------

# Read fields without details
$f = $emarsys.getFields($false)
$f | ft

# Read fields with details
$f = $emarsys.getFields($true)
$f | Out-GridView


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# Test the change of the concat character for lists and messages
$settings.nameConcatChar = " | "

# Load lists
$lists = $emarsys.getLists()

# Show lists blank
$lists | ft

# Show lists with toString
$lists | Select *, @{name="toString";expression={ $_.toString() }} -exclude raw | ft

# Show lists with counts
( $lists | Select *,  @{name="count";expression={ $_.count() }} -exclude raw )| ft


#-----------------------------------------------
# MAILINGS
#-----------------------------------------------

# Get Mailings
$mailings = $emarsys.getEmailCampaigns()

# Show mailings
$mailings | select * -exclude raw | ft

# Get Mailings with toString
$mailings | Select id, name, @{name="toString";expression={ $_.toString() }} | ft



exit 0

# Other calls


$emarsys.getEmailTemplates() 
$emarsys.getAutomationCenterPrograms()
$emarsys.getExternalEvents()
$emarsys.getLinkCategories()
$emarsys.getSources()
$emarsys.getAutoImportProfiles()
$emarsys.getConditionalTextRules()


#Invoke-emarsys -uri "$( $settings.base )settings" -cred $cred



#-----------------------------------------------
# PREVIEW
#-----------------------------------------------

$selectedCampaigns | ForEach {
    $id = $_.id 
    $url = "https://trunk-int.s.emarsys.com/api/v2/email/$( $id )/preview"
    $preview = Invoke-RestMethod -uri $url -Method Post -Headers $header -Verbose -Body "{""version"": ""html""}"
    $preview.data
}

exit 0

