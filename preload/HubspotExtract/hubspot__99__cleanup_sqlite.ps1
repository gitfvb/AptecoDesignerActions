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
$processId = [guid]::NewGuid()
$modulename = "hubspot_cleanup"

$settings = @{
    foldersToCleanUp = @(
        "C:\Apteco\Build\Hubspot\preload\HubspotExtract\extract"
        "C:\Apteco\Build\Hubspot\preload\HubspotExtract\backup"
    ) 
    maxAgeBeforeRemoval = 3
    logfile = "$( $scriptPath )\hubspot_extract.log"
    sqliteDb = "C:\Apteco\Build\Hubspot\data\hubspot.sqlite" # TODO [ ] replace the first part of the path with a designer environment variable
    exportDir = "$( $scriptPath )\extract\$( $processId )\"

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
# CLEANUP FILES AND FOLDERS
#
################################################

$settings.foldersToCleanUp | foreach {
    
    $destination = $_

    [array]( Get-ChildItem $destination -Attributes Directory ) | ForEach {
            
        $directoryToCheck = $_

        # Assumes that first part of a directory name is a datetime as a minimum and other information follows after an underscore
        $directoryTimeStamp = ( $directoryToCheck.Name -split "_" )[0]

        $age = [datetime]::Now - [datetime]::ParseExact($directoryTimeStamp,"yyyyMMddHHmmss",$null)

        if ( $age.days -gt $settings.maxAgeBeforeRemoval ) {
            
            Write-Log -message "Removing ""$( $directoryToCheck.FullName )"" because it is ""$( $age.days )"" days old"
                
            Remove-Item -Path $directoryToCheck.FullName -Recurse

        }

    }

}



################################################
#
# CLEANUP SQLITE DATABASE
#
################################################


<#


use rank to delete not needed versions
"DELETE FROM jobs WHERE rowid NOT IN (SELECT min(rowid) FROM jobs GROUP BY JobId)" | .\sqlite3.exe .\jobs2.sqlite
"VACUUM" | .\sqlite3.exe .\jobs2.sqlite


#>