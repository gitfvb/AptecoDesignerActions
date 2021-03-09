
################################################
#
# INPUT
#
################################################

Param(
    [String]$scriptPath
    #[hashtable] $params
)

$params = [hashtable]@{
    scriptPath = $scriptPath
}


#-----------------------------------------------
# NOTES
#-----------------------------------------------

<#

# TODO [ ] Delta Extracts are not supported yet, but could be easily done through the xml file, that is read at the beginning

#>

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {

    $Env:BUILDDIR = "C:\Apteco\Build\20210308"

    
    $params = [hashtable]@{
        "scriptPath" = "C:\Apteco\Build\20210308\postextract"
    }
    
}

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
$moduleName = "ENRICHGEOCODE"
$processId = [guid]::NewGuid()


# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = [Hashtable]@{
    logfile = "$( $Env:BUILDDIR )\log\geocode.log"
    changeTLS = $true
    processingFolder = "$( $Env:BUILDDIR )\postextract\0_processing"
    extractDefinitions = @(
        [Hashtable]@{
            reference = "Household URN"
            addressFields = @(
                "Address"
                "Town"
                "Region"
                "Postcode"
                )
            name = "Households"
            #filename = "C:\Apteco\Build\20210308\extract\Households.txt" # TODO [ ] maybe load this information on the fly
            #encoding = "utf-8"    # TODO [ ] maybe load this information on the fly
        }
    )
}

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

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}



################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

#Add-Type -AssemblyName System.Data

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}
<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}
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

$checkfolders = @(
    $settings.processingFolder
)

$checkfolders | ForEach {
    $folder = $_
    if ( !(Test-Path -Path $folder) ) {
        Write-Log -message "Upload $( $folder ) does not exist. Creating the folder now!"
        New-Item -Path "$( $folder )" -ItemType Directory
    }
}


#-----------------------------------------------
# LOAD ALL EXTRACTS
#-----------------------------------------------

$extractInfos = Get-Childitem -Path "$( $Env:BUILDDIR )\extract" -Filter "*.info.xml"

$extracts = [System.Collections.ArrayList]@()
$extractInfos | ForEach {
    $f = $_
    $c = Get-Content -Path $f.FullName -Encoding UTF8 -Raw
    $x = [xml]$c
    [void]$extracts.Add($x.ExtractFileSummary)
}


#-----------------------------------------------
# EXTRACT ID + ADRESSFIELDS + GENERATE MD5 HASH
#-----------------------------------------------

$t = Measure-Command {

    $settings.extractDefinitions | ForEach {

        #--------------------------------------------------------------
        # extract preparation
        #--------------------------------------------------------------

        $extract = $_

        # Load the column definition
        $columnsToExtract = [System.Collections.ArrayList]@()
        [void]$columnsToExtract.Add( $extract.reference )
        [void]$columnsToExtract.AddRange( $extract.addressFields )

        # Load current data from extract
        $currentExtract = $extracts.where({ $_.Table -eq $extract.name })


        #--------------------------------------------------------------
        # create the sessionstate for the runspace pool to share functions and variables
        #--------------------------------------------------------------

        # Reference: https://devblogs.microsoft.com/scripting/powertip-add-custom-function-to-runspace-pool/                
        # and https://docs.microsoft.com/de-de/powershell/scripting/developer/hosting/creating-an-initialsessionstate?view=powershell-7.1
        $iss = [initialsessionstate]::CreateDefault()

        # create sessionstate function entries
        @("Convert-HexToByteArray","Convert-ByteArrayToHex","Get-StringHash") | ForEach {
            $functionName = $_
            $definition = Get-Content "Function:\$( $functionName )" -ErrorAction Stop                
            $sessionStateFunction = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($functionName, $definition)
            $iss.Commands.Add($sessionStateFunction)
        }       

        # create sessionstate variable entries
        $variablesToPass = [Hashtable]@{
            "extractAddressFields" = $settings.extractDefinitions[0].addressFields
        }
        ForEach ($key in $variablesToPass.keys) {
            $var = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($key,$variablesToPass.$key,"")
            $iss.Variables.Add($var)
        }


        #--------------------------------------------------------------
        # create additional columns / expressions on the fly for the CSV
        #--------------------------------------------------------------

        $additionalColumns = [System.Collections.ArrayList]@(
            [Hashtable]@{name="AddressHash";expression = {
                $row = $_
                $addressString=[System.Collections.ArrayList]@()
                @( $extractAddressFields ) | ForEach {
                    [void]$addressString.add( $row.$_ )
                }
                Get-StringHash -inputString ( $addressString -join "|" ) -hashName "MD5"
            }}
        )       

        # Arguments for Filesplitting
        $params = @{
            inputPath = $currentExtract.Filename
            inputDelimiter = "`t"
            outputDelimiter = "`t"
            writeCount = 150000
            batchSize = 150000
            chunkSize = 2000
            throttleLimit = 30
            header = $true
            writeHeader = $true
            outputColumns = $columnsToExtract
            #outputDoubleQuotes = $false
            outputFolder = $settings.processingFolder
            additionalColumns = $additionalColumns
            initialsessionstate = $iss
        }

        # Split the file and remember the IDs
        $extract | Add-Member -MemberType NoteProperty -Name "splitID" -Value ( Split-File @params )

    }

}

Write-Log -message "Extract and hashing of addresses done in $( $t.TotalSeconds ) seconds"


#-----------------------------------------------
# CHECK HASH VALUES AGAINST EXISTING VALUES IN DATABASE
#-----------------------------------------------

$t = Measure-Command {

    $settings.extractDefinitions | ForEach {

        $extract = $_
        $splitID = $extract.splitID

        # Go through every splitted file
        Get-ChildItem -Path "$( $settings.processingFolder )\$( $splitID )" -Filter "*.part*" | ForEach {

            $sf = $_
            $csv = Import-Csv -Path $sf.FullName -Delimiter "`t" -Encoding UTF8 -Verbose

            foreach ($row in $csv) {

            }
            
            # Export the csv file again
            #$csv | Export-Csv -Path "$( $settings.processingFolder )\$( $splitID )\test.csv" -encoding UTF8 -NoTypeInformation -Delimiter "`t" -Append

        }

    }

}

Write-Log -message "Checking of address hash done in $( $t.TotalSeconds ) seconds"


exit 0


#-----------------------------------------------
# BATCH GEOCODE DIFFERENCE ROWS
#-----------------------------------------------


#-----------------------------------------------
# FILL DATABASE WITH NEW DATA
#-----------------------------------------------


#-----------------------------------------------
# WRITE DATA TO CSV
#-----------------------------------------------

# Only data from csv is read directly from Designer


#-----------------------------------------------
# WRAP UP
#-----------------------------------------------




exit 0
