

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


#-----------------------------------------------
# DEFINE THE SETTINGS
#-----------------------------------------------

try {
    $settings = ( Get-Content -Path ".\settings.json" -ReadCount 0 ) | ConvertFrom-Json #-Depth 99
} catch {
    Write-Host "Something is wrong with the settings file: '$( $_.Exception.Message )'"
    Write-Host "-----------------------------------------------"
    Exit 1
}
Write-Host "Found $( $settings.count ) join operations in the settings"

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
    # EXECUTE THE JOINS
    #-----------------------------------------------

    Write-Host "Jumping into the loop, here we go!"

    $settings.objects | ForEach {

        $item = $_

        # Settings
        $inputFile = $item.inputFile

        # Check if this is incremental or delta, in this case we need to ensure some things
        If ( $item.incremental -eq $true -or $item.delta -eq $true ) {
            # Backup this files and the ones to add
            # [ ] TODO this need to be done
            #Copy-Item -Path $inputFile -Destination 
        } else {
            # Just proceed
        }

        Write-Host "Done with the first file. Now add other files"

        $item.filesToAdd | ForEach {

            $itemToAdd = $_

            # Check first rows first and compare headers
            Write-Host "Checking '$( $itemToAdd.path )' with prefix '$( $itemToAdd.columnPrefix )'"

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

