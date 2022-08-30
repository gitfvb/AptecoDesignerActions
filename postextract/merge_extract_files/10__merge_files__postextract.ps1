

################################################
#
# NOTES
#
################################################

<#

* In Designer create a BASE variable with the path to this system like D:\Apteco\Build\Holidays
* Have a look at the $settings creation script `00__create_settings__postextract.ps1` and customise it to your needs
* In Designer
  * Add a prefix to the columns for the files/extracts to join and put it in the columnPrefix setting
  * This prefix will be removed and then the columns will be checked if they are the same
  * Add the DataSources to your "Table Relationships" in Designer, but do not connect them
  * Do not forget to add the Variables to a hidden folder in "Folder Structure" in Designer
* Do not define any variables as "Reference", this can have an effect on the column ordner
  which needs to be exactly the same in all files (the script checks this!)

!!!
If you use incremental or delta extracts, make sure to implement a postload action which brings back the original file before appending the data
!!!

#>

################################################
#
# FUNCTIONS
#
################################################

Function Count-Rows {

    param(
        [Parameter(Mandatory=$false)][string]$Path
    )

    $c = [long]0

    Get-Content -Path $Path -ReadCount 1000 | ForEach {
        $c += $_.Count
    }

    # Return
    $c

}


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
Write-Host "Starting to join extract files"
Write-Host "Current Path: '$( Get-Location )'"


#-----------------------------------------------
# READ ENVIRONMENT VARIABLE BASE
#-----------------------------------------------

# Get one environment variable from Designer
# This variable should be defined in Designer as it does not send the current directory by default
$base = [System.Environment]::GetEnvironmentVariable("BASE")
#$base = "C:\Apteco\Build\20220714"

# Check result
If ( $base -eq $null ) {
    Write-Host "Base variable not existing. Please set up"
    Write-Host "-----------------------------------------------"
    exit 1
} else {
    Write-Host "Base variable is existing: $( $base )"
}


#-----------------------------------------------
# DEFINE THE SETTINGS
#-----------------------------------------------
<#
Write-Host "Creating settings"

$settings = [Hashtable]@{
    "objects" = [Array]@(


        [PSCustomObject]@{
            "inputFile" = "$( $base )\extract\People.txt"
            "filesToAdd" = [Array]@(

                [PSCustomObject]@{
                    columnPrefix = "DE" # this will be removed, but it needed for designer not to complain about duplicate names
                    path = "$( $base )\extract\PeopleDE.txt"
                }

            )
            "addedFilesEncoding" = "utf8" #[System.Text.Encoding]::UTF8.CodePage
            "removeHeadersFromAddedFiles" = $true
            "outputEncoding" = "utf8" #[System.Text.Encoding]::UTF8.CodePage
            "outputFile" = "$( $base )\extract\People.txt"
        }


    )
}
#>

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
    # EXECUTE THE JOINS
    #-----------------------------------------------

    Write-Host "Jumping into the loop, here we go!"

    $settings.objects | ForEach {

        $item = $_

        # Settings
        $inputFile = $item.inputFile

        # Temporary file
        $tmpFileString = "$( $item.outputFile ).tmp"
        If ( Test-Path -Path $tmpFileString ) {
            Remove-Item -Path $tmpFileString
        }
        $tmpFile = New-Item -Path $tmpFileString -ItemType File

        # Check if this is incremental or delta, in this case we need to ensure some things
        If ( $item.incremental -eq $true -or $item.delta -eq $true ) {
            # Backup this files and the ones to add
            # [ ] TODO this need to be done
            #Copy-Item -Path $inputFile -Destination 
        } else {
            # Just proceed
        }

        # Counting
        Write-Host "Found $( Count-Rows -Path $inputFile ) rows in the input file (including headers)"

        # Reading first 200 rows for comparison, it is 201 to include the header
        $fileHead = Get-Content -Path $inputFile -ReadCount 100 -TotalCount 201 -Encoding $item.addedFilesEncoding
        $csv =  $fileHead | ConvertFrom-Csv  -Delimiter "`t"

        Write-Host "Checking first $( $csv.count ) lines for comparison of columns"

        #$csv | Export-Csv -Path $tmpFile -Encoding utf8 -NoTypeInformation -Delimiter "`t" #-Append
        
        # Write the first file
        Write-Host "Now write the first file"
        Get-Content -Path $inputFile -ReadCount 100 -Encoding $item.addedFilesEncoding | Add-Content -Path $tmpFile -Encoding $item.outputEncoding

        Write-Host "Done with the first file. Now add other files"

        $item.filesToAdd | ForEach {

            $itemToAdd = $_

            # Check first rows first and compare headers
            Write-Host "Checking '$( $itemToAdd.path )' with prefix '$( $itemToAdd.columnPrefix )'"
            $addFileHead = Get-Content -Path $itemToAdd.path -ReadCount 100 -TotalCount 201 -Encoding $item.addedFilesEncoding
            $addCsv =  $addFileHead | ConvertFrom-Csv  -Delimiter "`t"
            $addHeaders = [Array]@()
            $addCsv[0].psobject.properties.name | ForEach {
                $addHeaders += $_ -Replace "^$( $itemToAdd.columnPrefix )", "" # $_.TrimStart("DE")
            }

            $fieldComparation = Compare-Object -ReferenceObject $csv[0].psobject.properties.name -DifferenceObject $addHeaders -IncludeEqual -SyncWindow 0
            $equalColumns = ( $fieldComparation | where { $_.SideIndicator -eq "==" } ).InputObject
            $columnsOnlySourceFile = ( $fieldComparation | where { $_.SideIndicator -eq "=>" } ).InputObject
            $columnsOnlyAddFile = ( $fieldComparation | where { $_.SideIndicator -eq "<=" } ).InputObject

            #$fieldComparation

            # If good, add all other content
            #Get-Content -Path $inputFile -ReadCount 100 -Encoding $item.addedFilesEncoding
            $doOperation = $true
            If ( $equalColumns.Count -gt 0 ) {
                
                If ( $columnsOnlySourceFile.Count -gt 0 ) {
                    $doOperation = $false
                    Write-Host "Following fields are only in the source file or wrong order: $( $columnsOnlySourceFile -join ", " )"
                }

                If ( $columnsOnlyAddFile.Count -gt 0 ) {
                    $doOperation = $false
                    Write-Host "Following fields are only in the file to add or wrong order: '$( $columnsOnlyAddFile -join ", " )'"
                }

                If ( $doOperation -eq $true ) {
                    
                    Write-Host "Check for '$( $itemToAdd.path )' ok, so add it!"

                    # Counting
                    Write-Host "Found $( Count-Rows -Path $itemToAdd.path ) rows in the input file (including headers)"

                    # Check if we should ignore the first header line
                    if ( $item.removeHeadersFromAddedFiles ) {
                        $removeFirstLine = $true
                    } else {
                        $removeFirstLine = $false
                    }
                    
                    # Read and write the files
                    $i = 0
                    Get-Content -Path $itemToAdd.path -ReadCount 100 -Encoding $item.addedFilesEncoding | ForEach {
                        $chunk = $_
                        if ( $removeFirstLine -eq $true ) {
                            Write-Host "Removing first line"
                            $chunk = $chunk[1..( $chunk.Count -1 )]
                            $removeFirstLine = $false
                        } 
                        #Write-Host "Writing $( $chunk.count ) rows"
                        $chunk | Add-Content -Encoding $item.addedFilesEncoding -Path $tmpFile
                        $i += $chunk.Count
                    }

                    Write-Host "Added $( $i ) rows to '$( $tmpFile )'"

                } else {
                    Write-Host "Didn't add this file"
                    If ( $settings.generateErrorOnNonSuccess -eq $true ) {
                        Write-Host "Creating an error on a failure! Change settings, if this is not your wish."
                        throw [System.IO.InvalidDataException] "Joining failed"
                    }
                }

            }

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

        # Delete original file, if exists
        If (( Test-Path -Path $item.outputFile ) -eq $true) {
            Remove-Item -Path $item.outputFile -Force -Verbose
            Write-Host "Removed file '$( $item.outputFile )'"
        }

        # Rename temporary file to original one
        Rename-Item -Path $tmpFile -NewName $item.outputFile -Verbose
        Write-Host "Renaming file '$( $tmpFile )' to '$( $item.outputFile )'"

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

