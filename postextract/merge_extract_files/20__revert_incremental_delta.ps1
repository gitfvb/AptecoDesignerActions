

################################################
#
# NOTES
#
################################################

<#

!!!
If you use incremental or delta extracts, make sure to implement a postload action which brings back the original file before appending the data
!!!

#>


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
# FUNCTIONS
#
################################################




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
# START
#
################################################

Write-Host "-----------------------------------------------"
Write-Host "Starting to revert the extracted files"
Write-Host "Current Path: '$( Get-Location )'"


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# READ ENVIRONMENT VARIABLE BASE
#-----------------------------------------------

# Get one environment variable from Designer
# This variable should be defined in Designer as it does not send the current directory by default
If ( $debug -eq $true ) {
    $base = [System.Environment]::GetEnvironmentVariable("BASE")
} else {
    $base = "C:\faststats\build\Reisen"
}

# Check result
If ( $base -eq $null ) {
    Write-Host "Base variable not existing. Please set up"
    Write-Host "-----------------------------------------------"
    exit 1
} else {
    Write-Host "Base variable is existing: $( $base )"
}


#-----------------------------------------------
# READ SETTINGS FILE
#-----------------------------------------------

$logfile = ".\merge.log"
$functionsSubfolder = ".\functions"

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# $settings | ConvertTo-Json -Depth 99
try {
    $settings = ( Get-Content -Path ".\settings.json" -ReadCount 0 ) | ConvertFrom-Json #-Depth 99
} catch {
    Write-Host "Something is wrong with the settings file: '$( $_.Exception.Message )'"
    Write-Host "-----------------------------------------------"
    Exit 1
}
Write-Host "Found $( $settings.count ) join operations in the settings"


#-----------------------------------------------
# LOG ALL OTHER ENVIRONMENT VARIABLES
#-----------------------------------------------

If ( $settings.logAllEnvironmentVariables -eq $true) {
    Write-Host "Logging all environment variables"
    # Get all Environment variables
    [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process).GetEnumerator() | ForEach {
        Write-Host "$( $_.Name ) = $( $_.Value )"
    }
}


#-----------------------------------------------
# PROCEED
#-----------------------------------------------

$success = $false
try {

    ################################################
    #
    # TRY
    #
    ################################################


    #-----------------------------------------------
    # REVERT FILES
    #-----------------------------------------------

    Write-Host "Jumping into the loop, here we go!"

    $settings.objects | ForEach {

        $item = $_

        # Settings
        $inputFile = $item.inputFile

        Write-Host "Checking '$( $inputFile )'"

        # Check if this is incremental or delta, in this case we need to ensure some things
        If ( $item.incremental -eq $true -or $item.delta -eq $true ) {

            Write-Host "This file is incremental or delta, so reverting it"
            
            # Removing original file
            $backupFileString = "$( $inputFile )$( $settings.backupExtension )"

            If ( (Test-Path -Path $inputFile) -eq $true -and (Test-Path -Path $backupFileString) -eq $true ) {
                
                Write-Host "Removing previous original file '$( $inputFile )'"
                Remove-Item -Path $inputFile
                
                Write-Host "Copying backup file '$( $backupFileString )' to original file '$( $inputFile )'"
                Copy-Item -Path $backupFileString -Destination $inputFile

            } else {
                
                Write-Host "Conditions not met. Proceeding."

            }
            

        } else {
            # Just proceed
        }
        
    }

    $success = $true

} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Host "Got exception during execution phase"
    Write-Host "  Type: '$( $_.Exception.GetType().Name )'"
    Write-Host "  Message: '$( $_.Exception.Message )'"
    Write-Host "  Stacktrace: '$( $_.ScriptStackTrace )'"
    
    throw $_.exception

} finally {

    # If successful
    If ( $success -eq $true ) {

    } else {

    }

    Write-Host "Done!"
    Write-Host "-----------------------------------------------"

    # Returning an error to Designer
    If ( $settings.generateErrorOnNonSuccess -eq $true -and $success -eq $false )  {
        Exit 1
    } else {
        Exit 0
    }

}

