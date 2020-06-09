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
        scriptPath = "C:\Apteco\Build\Hubspot\preload\Hubspot Extract"
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
$lastSessionFilename = "lastsession.json"
$processId = [guid]::NewGuid()

# Load last session
$lastSession = Get-Content -Path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

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
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

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
Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}

# Load all exe and dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe","*.dll") 





################################################
#
# MORE SETTINGS
#
################################################


# TODO [ ] load token from Designer environment variable

$token = "<hapikey>"
$base = "https://api.hubapi.com/"
$hapikey = "&hapikey=$( $token )"
$extractMethod = "FULL" # FULL|DELTA
$loadArchivedRecords = $true
$pageLimitGet = 100 # Max amount of records to download with one API call
$lastTimestamp = Get-Unixtime -timestamp ( (Get-Date).AddMonths(-1) ) -inMilliseconds
$currentTimestamp = Get-Unixtime -inMilliseconds


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
# CHECK CONNECTION AND LIMITS
#
################################################


$object = "integrations"
$apiVersion = "v1"

$url = "$( $base )$( $object )/$( $apiVersion )/limit/daily?$( $hapikey )"
$limits = Invoke-RestMethod -Method Get -Uri $url #-Headers $headers

# Current usage
$currentApiUsage = $limits.currentUsage

# Current limit
$currentApiLimit = $limits.usageLimit

# Exit if no limit is delivered
if (!($currentApiLimit -gt 0)) {
    throw [System.IO.InvalidDataException] "No connection available"
}



################################################
#
# LOAD CONTACTS PROPERTIES
#
################################################


$object = "properties"
$apiVersion = "v1"
$url = "$( $base )$( $object )/$( $apiVersion )/contacts/properties?$( $hapikey )"

$properties = Invoke-RestMethod -Method Get -Uri $url

# Find out different types of properties
#$properties | select -Unique groupName

# Show properties
#$properties | sort groupName | Out-GridView

#$allProperties = $properties.name -join ","


################################################
#
# LOAD CONTACTS
#
################################################

Switch ( $extractMethod ) {
    
    "FULL" {
        

        #-----------------------------------------------
        # FULL ACTIVE CONTACTS
        #-----------------------------------------------

        $object = "crm"
        $apiVersion = "v3"
        $limit = $pageLimitGet
        $archived = "false"
        $url = "$( $base )$( $object )/$( $apiVersion )/objects/contacts?limit=$( $limit )&archived=$( $archived )&properties=$( $properties.name -join "," )$( $hapikey )"

        $contacts = @()
        Do {
    
            # Get all contacts
            $contactsResult = Invoke-RestMethod -Method Get -Uri $url -Verbose
    
            # Add contacts to array
            $contacts += $contactsResult.results

            # Load next url
            $url = "$( $contactsResult.paging.next.link )$( $hapikey )"

        } while ( $url -ne $hapikey )


        #-----------------------------------------------
        # FULL ARCHIVED CONTACTS
        #-----------------------------------------------

        if ($loadArchivedRecords) {

            $object = "crm"
            $apiVersion = "v3"
            $limit = $pageLimitGet
            $archived = "true"
            $url = "$( $base )$( $object )/$( $apiVersion )/objects/contacts?limit=$( $limit )&archived=$( $archived )&properties=$( $properties.name -join "," )$( $hapikey )"

            $archivedContacts = @()
            Do {
    
                # Get all contacts
                $archivedContactsResult = Invoke-RestMethod -Method Get -Uri $url -Verbose
    
                # Add contacts to array
                $archivedContacts += $archivedContactsResult.results

                # Load next url
                $url = "$( $archivedContactsResult.paging.next.link )$( $hapikey )"

            } while ( $url -ne $hapikey )

        }

    }

    "DELTA" {


        #-----------------------------------------------
        # DELTA ACTIVE CONTACTS
        #-----------------------------------------------

        $object = "crm"
        $apiVersion = "v3"
        $limit = $pageLimitGet
        $url = "$( $base )$( $object )/$( $apiVersion )/objects/contacts/search?$( $hapikey )"

        $body = [ordered]@{
            "filterGroups" = @(
                @{
                    "filters" = @(
                        @{
                            "propertyName"="lastmodifieddate"
                            "operator"="GTE"
                            "value"= $lastTimestamp
                         }
                    )
                }
            )
            sorts = @("lastmodifieddate")
            #query = ""
            properties = $properties.name #@("firstname", "lastname", "email")
            limit = $limit
            after = 0
        } 
        
        $contacts = @()
        Do {
    
            # Get all contacts results
            $bodyJson = $body | ConvertTo-Json -Depth 8
            $contactsResult = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body $bodyJson -Verbose
    
            # Add contacts to array
            $contacts += $contactsResult.results

            # prepare next batch -> with search the "paging" does not contain IDs, it contains only integers the index of the search result
            $body.after = $contactsResult.paging.next.after

        } while ( $contactsResult.paging ) # only while the paging object is existing

        
        #-----------------------------------------------
        # DELTA ARCHIVED CONTACTS
        #-----------------------------------------------

        # At the moment there is no difference in archived and non-archived records in the search
        <#
        if ($loadArchivedRecords) {

            $object = "crm"
            $apiVersion = "v3"
            $limit = $pageLimitGet
            $archived = "true"
            $url = "$( $base )$( $object )/$( $apiVersion )/objects/search?$( $hapikey )"

            $body = [ordered]@{
                "filterGroups" = @(
                    @{
                        "filters" = @(
                            @{
                                "propertyName"="lastmodifieddate"
                                "operator"="GTE"
                                "value"= ( Get-Unixtime -timestamp ( (Get-Date).AddMonths(-1) ) -inMilliseconds )
                                }
                        )
                    }
                )
                sorts = @("lastmodifieddate")
                #query = ""
                properties = @("firstname", "lastname", "email")
                limit = 10
                after = 0
            } | ConvertTo-Json -Depth 8

            $archivedContacts = @()
            Do {
    
                # Get all contacts
                $archivedContactsResult = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body $body -Verbose
    
                # Add contacts to array
                $archivedContacts += $archivedContactsResult.results

                # Load next url
                $url = "$( $archivedContactsResult.paging.next.link )$( $hapikey )"

            } while ( $url -ne $hapikey )

        }
        #>



    }

}

################################################
#
# SAVE LAST LOADED TIMESTAMP
#
################################################

$lastSession = @{
    lastTimestamp = $currentTimestamp
    lastTimeStampHumanUTC = (Get-Date 01.01.1970).AddSeconds($currentTimestamp/1000)
}

# create json object
$lastSessionJson = $lastSession | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$lastSessionJson

# save settings to file
$lastSessionJson | Set-Content -path "$( $scriptPath )\$( $lastSessionFilename )" -Encoding UTF8




################################################
#
# EXPORT DATA INTO CSV
#
################################################




################################################
#
# LOAD CSV INTO SQLITE
#
################################################