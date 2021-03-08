
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
    <#
        "TransactionType" = "Replace"
        "Password" = "b"
        "scriptPath" = "D:\Scripts\ELAINE\Transactional"
        "MessageName" = "1875 / Apteco PeopleStage Training Automation"
        "EmailFieldName" = "c_email"
        "SmsFieldName" = ""
        "Path" = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_1875  Apteco PeopleStage Training Automation_f29a31c9-7935-4bf6-b55c-e2794ea36dba.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "1875 / Apteco PeopleStage Training Automation"
        "CommunicationKeyFieldName" = "Communication Key"
    #>
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
# EXTRACT ID + ADRESSFIELDS
#-----------------------------------------------
$t = Measure-Command {

    $settings.extractDefinitions | ForEach {

        $extract = $_

        # Load the column definition
        $columnsToExtract = [System.Collections.ArrayList]@()
        [void]$columnsToExtract.Add( $extract.reference )
        [void]$columnsToExtract.AddRange( $extract.addressFields )

        # Load current data from extract
        $currentExtract = $extracts.where({ $_.Table -eq $extract.name })

        # Arguments for Filesplitting
        $params = @{
            inputPath = $currentExtract.Filename
            inputDelimiter = "`t"
            outputDelimiter = "`t"
            writeCount = 150000
            batchSize = 150000
            chunkSize = 10000
            header = $true
            writeHeader = $true
            outputColumns = $columnsToExtract
            #outputDoubleQuotes = $false
            outputFolder = $settings.processingFolder
        }

        # Split the file and remember the ID
        $extract | Add-Member -MemberType NoteProperty -Name "splitID" -Value ( Split-File @params )

    }

}

Write-Log -message "Extract of addresses done in $( $t.TotalSeconds ) seconds"

#-----------------------------------------------
# PARSE THROUGH FILES AND GENERATE HASH
#-----------------------------------------------

$t = Measure-Command {

    $settings.extractDefinitions | ForEach {

        $extract = $_
        $splitID = $extract.splitID

        # Go through every splitted file
        Get-ChildItem -Path "$( $settings.processingFolder )\$( $splitID )" -Filter "*.part*" | ForEach {

            $sf = $_
            $csv = Import-Csv -Path $sf.FullName -Delimiter "`t" -Encoding UTF8 -Verbose

            # Generate the combined address string, joined with pipe character and then hash it
            <#
            Workflow TestParallel{
                Foreach -parallel( $row in $csv ){
                    $addressString=[System.Collections.ArrayList]@()
                    $extract.addressFields | ForEach {
                        [void]$addressString.add( $row.$_ )
                    }
                    $row | Add-Member -MemberType NoteProperty -Name "AddressHash" -Value ( Get-StringHash -inputString ( $addressString -join "|" ) -hashName "SHA256" )
                }
            }
            
            
            TestParallel
            #>

            foreach ($row in $csv) {
                $addressString=[System.Collections.ArrayList]@()
                $extract.addressFields | ForEach {
                    [void]$addressString.add( $row.$_ )
                }
                # On my surface pro 7 with i5 I got 230 SHA256 hashes per second -> 220 seconds for 50k rows
                # With MD5 it is 345 hashes per second -> 145 seconds for 50k rows
                # In total we have to subtract around 30 seconds as this is needed to combine the address columns to a string
                #$row | Add-Member -MemberType NoteProperty -Name "AddressHash" -Value ( $addressString -join "|" )
                $row | Add-Member -MemberType NoteProperty -Name "AddressHash" -Value ( Get-StringHash -inputString ( $addressString -join "|" ) -hashName "MD5" )
            }
            
            # Export the csv file again
            $csv | Export-Csv -Path "$( $settings.processingFolder )\$( $splitID )\test.csv" -encoding UTF8 -NoTypeInformation -Delimiter "`t" -Append

        }

    }

}

Write-Log -message "Hashing of addresses done in $( $t.TotalSeconds ) seconds"


exit 0



#$csv | select -first 10 *, @{name="AddressHash";expression={ Get-StringHash -inputString  -hashName "SHA256" }} | ft
#$extract.addressFields -join "|"


#-----------------------------------------------
# CHECK HASH VALUES AGAINST EXISTING VALUES IN DATABASE
#-----------------------------------------------


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

Write-Host "---------------------"

# Load another script into cache
. "$( $Env:BUILDDIR )\postextract\functions\Count-Rows.ps1"

# Load all extract files
$extractFiles = Get-ChildItem -Path "$( $Env:BUILDDIR )\extract\*.txt" -Exclude "*.stats.*"

# Count all rows through script as an example
$extractFiles | ForEach {
    $f = $_
    $count = Count-Rows -inputPath $f -header $true
    Write-Host "$( $f.name ) has $( $count ) rows"
}

Write-Host "---------------------"