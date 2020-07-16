
################################################
#
# INPUT
#
################################################


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
$processId = [guid]::NewGuid()
$modulename = "sqlserver_housekeeping"
$timestamp = [datetime]::Now

$settings = @{

    # DB shrinking
    instances = @( "F9517BC" )
    dbExclude = @( "master","model","msdb","tempdb" )
    ownerExclude = @( "sa" )
    

    # General
    logfile = "$( $scriptPath )\housekeeping.log"

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


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################





################################################
#
# EXECUTE SQL SCRIPTS
#
################################################

# General scripts to execute

Get-ChildItem -Path ".\sql\*" -Include @( "*.sql" ) | Sort { $_.Name } | ForEach {

    $file = $_

    $file.FullName

    Invoke-Sqlcmd -InputFile $file -Verbose # -ServerInstance -Database 

}

# If there are other scripts that we can identify by a prefix, put it in a subfolder like "prefix_ws", then all ws_ databases will be used for those scripts

$scriptsWithPrefix = @()
Get-ChildItem -Path ".\sql\*" -Include @( "*.sql" ) -Recurse | where { ( $_.DirectoryName -split "\\" )[-1] -like "*prefix*" } | Sort { $_.Name } | ForEach {
    
    $file = $_
    
    # Extract the prefix
    $prefix = (( $_.DirectoryName -split "\\" )[-1] -split "_" )[-1]

    $scriptsWithPrefix += [PSCustomObject]@{
        prefix = $prefix
        fullname = $file.FullName
    }

}

################################################
#
# SHRINK DATABASE AND FILES
#
################################################


$settings.instances | ForEach {
    
    $instance = $_
    $instance

    Write-Log "Checking instance '$( $instance )'"

    Get-SqlDatabase -ServerInstance $instance | where { $_.Owner -notin $settings.ownerExclude -or $_.Name -notin $settings.dbExclude } | ForEach {

        $db = $_

        Write-Log "Checking database '$( $db.Name )'"
        
        # Check if there are some scripts to execute with the prefix
        $scriptsWithPrefix | ForEach {
            
            $script = $_    

            # Executing the script as scalar to execute delete, update etc.
            If ( $db.Name.StartsWith($script.prefix,'CurrentCultureIgnoreCase') ) {
                $query = Get-Content -Path "$( $script.FullName )" -Encoding UTF8
                $result = Invoke-SqlServer -query $query -database $db.Name -instance $instance -executeScalar
                Write-Log "Executed '$( ( Get-Item $script.fullname ).Name )' with the result of '$( $result )' records"
            }

        }
                  
        # Shrink the database
        $shrinkDatabaseCommand = "DBCC SHRINKDATABASE(N'$( $db.Name )' )"
        Invoke-SqlServer -query $shrinkDatabaseCommand -database $db.Name -instance $instance
        Write-Log "Shrinked database '$( $db.Name )'"

        # Shrink the files
        $shrinkFilesCommand = "DBCC SHRINKFILE(N'$( $db.Name )'  , TRUNCATEONLY)"
        Invoke-SqlServer -query $shrinkFilesCommand -database $db.Name -instance $instance
        Write-Log "Shrinked files for '$( $db.Name )'"


        # Shrink the log files
        $shrinkLogCommand = "DBCC SHRINKFILE(N'$( $db.Name )_log' )"
        Invoke-SqlServer -query $shrinkLogCommand -database $db.Name -instance $instance
        Write-Log "Shrinked log file for '$( $db.Name )'"


    }

}



