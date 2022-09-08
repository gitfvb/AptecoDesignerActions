
################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


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
# SCRIPT ROOT
#
################################################

#-----------------------------------------------
# READ ENVIRONMENT VARIABLE BASE
#-----------------------------------------------

# Get one environment variable from Designer
# This variable should be defined in Designer as it does not send the current directory by default
$base = [System.Environment]::GetEnvironmentVariable("BASE")
#$base = "C:\Apteco\Build\20220714"

# Check result
If ( $base -eq $null ) {
    Write-Host "Base variable not existing. Please set up or execute this script from Designer."
    exit 1
} else {
    Write-Host "Base variable is existing: $( $base )"
}


#-----------------------------------------------
# DEFINE THE SETTINGS
#-----------------------------------------------

Write-Host "Creating settings"

$settings = [Hashtable]@{
    "objects" = [Array]@(


        [PSCustomObject]@{
            "inputFile" = "$( $base )\extract\People.txt"
            "filesToAdd" = [Array]@(

                [PSCustomObject]@{
                    columnPrefix = "PE" # this will be removed, but it needed for designer not to complain about duplicate names
                    path = "$( $base )\extract\PeopleDE2.txt"
                }

            )
            "addedFilesEncoding" = "utf8" #[System.Text.Encoding]::UTF8.CodePage
            "removeHeadersFromAddedFiles" = $true
            "outputEncoding" = "utf8" #[System.Text.Encoding]::UTF8.CodePage
            "outputFile" = "$( $base )\extract\People.txt"
            "incremental" = $false      # Please check if this is an incremental file, because if those we need to backup this first
            "delta" = $false            # Please check if this is an delta file, because if those we need to backup this first
        }


    )
    "logAllEnvironmentVariables" = $false
    "generateErrorOnNonSuccess" = $true
}

$settings | ConvertTo-Json -Depth 99 | Set-Content -Path ".\settings.json" -Encoding utf8

exit 0