
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
  * Add the DataSources to your "Table Relationships" in Designer, but do not connect them, add the checkbox for "Include in Build"
  * Do not forget to add the Variables to a hidden folder in "Folder Structure" in Designer
* Do not define any variables as "Reference", this can have an effect on the column ordner
  which needs to be exactly the same in all files (the script checks this!)

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
    # CREATE TEMP FOLDER
    #-----------------------------------------------

    $temp = "$( [System.Environment]::GetEnvironmentVariable("TEMP") )\$( [guid]::NewGuid().toString() )\"
    $tempCreation = New-Item -Path $temp -ItemType Directory


    #-----------------------------------------------
    # EXECUTE THE JOINS
    #-----------------------------------------------

    Write-Host "Jumping into the loop, here we go!"

    $settings.objects | ForEach {

        $item = $_

        # Settings
        $inputFile = $item.inputFile
        Write-Host "Checking '$( $inputFile )'"

        # Temporary file
        $tmpFileString = "$( $item.outputFile )$( $settings.temporaryExtension )"
        If ( Test-Path -Path $tmpFileString ) {
            Write-Host "Removing previous temporary file '$( $tmpFileString )'"
            Remove-Item -Path $tmpFileString
        }
        Write-Host "Creating new temporary file at '$( $tmpFileString )'"
        $tmpFile = New-Item -Path $tmpFileString -ItemType File

        # Backup this file anyway
        $backupFileString = "$( $inputFile )$( $settings.backupExtension )"
        If ( Test-Path -Path $backupFileString ) {
            Write-Host "Removing previous backup file '$( $backupFileString )'"
            Remove-Item -Path $backupFileString
        }
        Write-Host "Copying file '$( $inputFile )' to backup file '$( $backupFileString )'"
        Copy-Item -Path $inputFile -Destination $backupFileString

        # Counting
        Write-Host "Found $( Count-Rows -Path $inputFile ) rows in the input file (including headers)"

        # Reading first 200 rows for comparison, it is 201 to include the header
        $fileHead = Get-Content -Path $inputFile -ReadCount 100 -TotalCount 201 -Encoding $item.addedFilesEncoding
        $csv =  $fileHead | ConvertFrom-Csv  -Delimiter "`t"
        $headers = $csv[0].psobject.properties.name

        Write-Host "Checking first $( $csv.count ) lines for comparison of columns"

        #$csv | Export-Csv -Path $tmpFile -Encoding utf8 -NoTypeInformation -Delimiter "`t" #-Append
        
        # Write the first file
        Write-Host "Now write the first file"
        Get-Content -Path $inputFile -ReadCount 100 -Encoding $item.addedFilesEncoding | Add-Content -Path $tmpFile -Encoding $item.outputEncoding

        Write-Host "Done with the first file. Now add other files"

        $item.filesToAdd | ForEach {

            $itemToAdd = $_

            # Check if the file exists
            $itemToAddExisting = Test-Path -Path $itemToAdd.path

            If ( $itemToAddExisting -eq $true ) {
    
                Write-Host "File $( $itemToAdd.path ) is existing"

                # Count the rows
                $itemToAddRowsCount = Count-Rows -Path $itemToAdd.path
                Write-Host "Found $( $itemToAddRowsCount ) rows in the input file (including headers)"

                If ( $itemToAddRowsCount -gt 1 ) {
                
                    # Check first rows first and compare headers
                    Write-Host "Checking '$( $itemToAdd.path )' with prefix '$( $itemToAdd.columnPrefix )'"
                    $addFileHead = Get-Content -Path $itemToAdd.path -ReadCount 100 -TotalCount 201 -Encoding $item.addedFilesEncoding
                    $addCsv =  $addFileHead | ConvertFrom-Csv  -Delimiter "`t"
                    $addHeaders = [Array]@()
                    $addCsv[0].psobject.properties.name | ForEach {
                        $addHeaders += $_ -Replace "^$( $itemToAdd.columnPrefix )", "" # $_.TrimStart("DE")
                    }

                    $fieldComparation = Compare-Object -ReferenceObject $headers -DifferenceObject $addHeaders -IncludeEqual #-SyncWindow 0 # SyncWindows checks the order of the columns
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
                            Write-Host "Following fields are only in the file to add: $( $columnsOnlySourceFile -join ", " )"
                        }

                        If ( $columnsOnlyAddFile.Count -gt 0 ) {
                            $doOperation = $false
                            Write-Host "Following fields are only in the source file: '$( $columnsOnlyAddFile -join ", " )'"
                        }

                        If ( $doOperation -eq $true ) {
                    
                            Write-Host "Check for '$( $itemToAdd.path )' ok, so add it!"

               

                            # Check if we should ignore the first header line
                            <#
                            if ( $item.removeHeadersFromAddedFiles ) {
                                $removeFirstLine = $true
                            } else {
                                $removeFirstLine = $false
                            }
                            #>
                    

                            # Rewrite the file first
                            Write-Host "Rewrite the files with columns in correct order and without header"
                            $params = @{
                                inputPath = $itemToAdd.path
                                inputDelimiter = "`t"
                                outputDelimiter = "`t"
                                writeCount = -1
                                batchSize = 500000
                                chunkSize = 50000
                                header = $true
                                writeHeader = $false
                                outputColumns = $headers | % { "$( $itemToAdd.columnPrefix )$( $_ )" }
                                outputDoubleQuotes = $false
                                outputFolder = $temp
                                #additionalColumns = $additionalColumns

                            }

                            # Split the file and remember the ID
                            $newID = Split-File @params
                            Write-Host "Rewritten the file with id '$( $newID )'"

                            # Read and append the file
                            $i = 0                            
                            $addItem = Get-Item -Path $itemToAdd.path
                            $temporaryAddItem = "$( $temp )\$( $newID )\$( $addItem.Name )"
                            Write-Host "Temporary file has $( ( Count-Rows -Path $temporaryAddItem ) ) rows"
                            Get-Content -Path $temporaryAddItem -ReadCount 10000 -Encoding $item.addedFilesEncoding | ForEach {
                                $chunk = $_
                                #Write-Host "Writing $( $chunk.count ) rows"
                                $chunk | Add-Content -Encoding $item.addedFilesEncoding -Path $tmpFile
                                $i += $chunk.Count
                            }
                    
                            Write-Host "Added $( $i ) rows to '$( $tmpFile )'"

                            # Delete original file, if exists
                            If (( Test-Path -Path $item.outputFile ) -eq $true) {
                                Write-Host "Removed file '$( $item.outputFile )'"
                                Remove-Item -Path $item.outputFile -Force #-Verbose
                            }

                            # Rename temporary file to original one
                            Write-Host "Renaming file '$( $tmpFile )' to '$( $item.outputFile )'"
                            Rename-Item -Path $tmpFile -NewName $item.outputFile #-Verbose

                            Write-Host "Done with file '$( $item.outputFile )'"



                        } else {

                            Write-Host "Didn't add this file"
                            If ( $settings.generateErrorOnNonSuccess -eq $true ) {
                                Write-Host "Creating an error on a failure! Change settings, if this is not your wish."
                                throw [System.IO.InvalidDataException] "Joining failed"
                            }

                        }

                    }



                } else {

                    Write-Host "Found only header line or less"

                }


            } else {

                Write-Host "File $( $itemToAdd.path ) not found!"

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
<#
    # If successful
    If ( $success -eq $true ) {

        # Delete original file, if exists
        If (( Test-Path -Path $item.outputFile ) -eq $true) {
            Write-Host "Removed file '$( $item.outputFile )'"
            Remove-Item -Path $item.outputFile -Force #-Verbose
        }

        # Rename temporary file to original one
        Write-Host "Renaming file '$( $tmpFile )' to '$( $item.outputFile )'"
        Rename-Item -Path $tmpFile -NewName $item.outputFile #-Verbose

    } else {

    }
    #>

    # Remove the temporary folder now
    Write-Host "Removing temporary folder at $( $temp )"
    Remove-Item -Path $temp -Recurse

    # Logging
    Write-Host "Done!"
    Write-Host "-----------------------------------------------"

    # Returning an error to Designer
    If ( $settings.generateErrorOnNonSuccess -eq $true -and $success -eq $false )  {
        Exit 1
    } else {
        Exit 0
    }

}

