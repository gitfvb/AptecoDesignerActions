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
	    scriptPath= "D:\Scripts\Inxmail\Mailing"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://apidocs.inxmail.com/xpro/rest/v1/

TODO [ ] implement paging

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "INXRESPONSES"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

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
$lastSessionFile = "$( $scriptPath )\lastsession.json"

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
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
        Write-Log -message "    $( $param )= ""$( $params[$param] )"""
    }
}





################################################
#
# PROGRAM
#
################################################



#-----------------------------------------------
# LOAD LAST EXTRACT
#-----------------------------------------------

If ( Test-Path -Path $lastSessionFile ) {
    $startFromScratch = $false
    $lastSession = Get-Content -Path "$( $lastSessionFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    $startFromScratch = $true
}


#-----------------------------------------------
# MORE SETTINGs
#-----------------------------------------------

$extractTimestamp = Get-Unixtime 
$earliestDate = "2021-01-10T00:00:00Z" # [Datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssK")
$extractMode = "full" # full|delta
#$extractMode = "delta" # full|delta


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}


#-----------------------------------------------
# LOAD DEFINITION
#-----------------------------------------------

# TODO [ ] Eventually add a "first" load definition


$loadDefs = [System.Collections.ArrayList]@(
    
    <#
    
    TODO [ ] create a template entry here
    
    #>

    [PSCustomObject]@{
        "description" = "lists"
        "object" = "lists" #/lists{?createdAfter,createdBefore}
        "urn" = "id"
        "extract" = @(
            [PSCustomObject]@{
                "type" = "full"
                "parameters" = [hashtable]@{
                    "createdAfter" = $earliestDate
                    #"pageSize" = 3
                }
                # do this to check if lists have been deleted or e.g. renamed
            }
            [PSCustomObject]@{
                "type" = "delta"
                "nextLink" = $lastSession.nextLinks.where( { $_.name -eq "lists"  } ).link
                # remember the lastID URL to receive new lists, or timestamps to see what changed since then
            }
        ) #full|delta
    }

    [PSCustomObject]@{
        "description" = "attributes"
        "object" = "attributes" 
        "urn" = "id"
        "extract" = @(
            [PSCustomObject]@{
                "type" = "full"
            }
            [PSCustomObject]@{
                "type" = "delta"
            }
        ) #full|delta
    }
<#
    [PSCustomObject]@{
        "description" = "sendings"
        "object" = "sendings" #/sendings{?mailingIds,listIds,sendingsFinishedBeforeDate,sendingsFinishedAfterDate}
        "urn" = "id"
        "extract" = @(
            [PSCustomObject]@{
                "type" = "delta"
                #"sendingsFinishedAfterDate" = "xxx"
                # remember the lastID URL to receive new lists
            }
        ) #full|delta
        "subObjects" = [System.Collections.ArrayList]@(
            [PSCustomObject]@{
                "description" = "sendingsprotocol"
                "object" = [ScriptBlock]{
                    "sendings/$( $parentObj.id )/protocol" # /sendings/{sendingId}/protocol
                }
                #"urn" = "id"
                "extract" = @(
                ) #full|delta
            }
        )
    }
#>
<#
    [PSCustomObject]@{
        "object" = "recipients" #/recipients{?attributes,subscribedTo,lastModifiedSince,email,attributes.attributeName,trackingPermissionsForLists,subscriptionDatesForLists,unsubscriptionDatesForLists}
        #"urn" = "id"
        "extract" = @(
            [PSCustomObject]@{
                "type" = "full"
                "attributes" = [ScriptBlock]{
                    ( $inxArr | where { $_.object -eq "attributes"  } | ForEach { ConvertFrom-Json $_.payload  } | select name ).name -join ","
                }
                # no more parameters
                # do this to check if lists have been deleted or e.g. renamed
            }
            [PSCustomObject]@{
                "type" = "delta"
                "createdAfter" = "xxx"
                # remember the lastID URL to receive new lists
            }
        ) #full|delta
    }
#>


        <#
    [PSCustomObject]@{
        "object" = "events/subscriptions" #/events/subscriptions{?listId,startDate,endDate,types,embedded,recipientAttributes}
        # $ curl 'https://api.inxmail.com/customer/rest/v1/events/subscriptions?listId=5&startDate=2021-05-27T05:27:55Z&endDate=2021-05-27T07:27:55Z&types=PENDING_SUBSCRIPTION,PENDING_SUBSCRIPTION_DONE&embedded=inx:recipient&recipientAttributes=firstName,lastName' -i -X GET
        "extract" = @(
            "full" = [PSCustomObject]@{
                # no more parameters
                # do this to check if lists have been deleted or e.g. renamed
            }
            "delta" = [PSCustomObject]@{
                "createdAfter" = "xxx"
                # remember the lastID URL to receive new lists
            }
        ) #full|delta
    }



    [PSCustomObject]@{
        "object" = "recipients" #/recipients{?attributes,subscribedTo,lastModifiedSince,email,attributes.attributeName,trackingPermissionsForLists,subscriptionDatesForLists,unsubscriptionDatesForLists}
        "extract" = @(
            "full" = [PSCustomObject]@{
                # no more parameters
                # do this to check if lists have been deleted
            }
            "delta" = [PSCustomObject]@{
                "attributes" = "" # comma separated list of attributes
                "lastModifiedSince" = "xxx" # TODO [ ] does this also include new recipients?
                # remember the lastID URL to receive new lists
            }
        ) #full|delta
    }

#>
)



#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

function Get-Inxmail {
    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][PSCustomObject] $definition
        ,[Parameter(Mandatory=$true)][String] $extractMode
        ,[Parameter(Mandatory=$false)][PSCustomObject] $parentObj = ""
    )
    
    begin {
        
        $inxArr = [System.Collections.ArrayList]@()

    }
    
    process {

        $definition | where { $_.extract.type -eq $extractMode } | ForEach {
    
            $loadDef = $_
            $extractSettings = $loadDef.extract.where({ $_.type -eq $extractMode })
            
            # Parse object url, if needed
            If ( $loadDef.object -is [scriptblock] ) {
                $objectUrl = $_.object.InvokeReturnAsIs()
            } else {
                $objectUrl = $loadDef.object
            }

            # Generate URI and additional query parameters
            if ( $extractSettings.nextLink ) {
                $uri = $extractSettings.nextLink
            } else {
                $uri = "$( $apiRoot )$( $objectUrl )"
            }
            if ( $extractSettings.parameters ) {
                $uri = Add-HttpQueryPart -Uri $uri -QueryParameter $extractSettings.parameters
            }

            # Prepare http parameters
            $params = [hashtable]@{
                Method = "Get"
                Uri = $uri
                Header = $header
                ContentType = "application/hal+json"
                Verbose = $true
            }

            # Load data in pages
            Do {

                $res = Invoke-RestMethod @params
            
                # Parse the data
                if ( $res._embedded ) {
                    $urnFieldName = $loadDef.urn
                    $firstProperty = ( $res._embedded | Get-Member -MemberType NoteProperty | select -first 1 ).Name
                    $records = $res._embedded.$firstProperty  #$res._embedded."inx:$( $loadDef.object  )"
                    $value =  $records | select @{name="object";expression={ $objectUrl }},
                                                @{name="urn";expression={ $_.$urnFieldName }},
                                                @{name="extract";expression={ $extractTimestamp }},
                                                @{name="payload";expression={ ConvertTo-Json -InputObject $_ <# -Compress #> }}
                    try {
                        [void]$inxArr.AddRange(
                            [System.Collections.ArrayList]@( $value )
                        )
                    } catch {
                    #    [void]$inxArr.Add($value)
                        "Hello world"
                    }
                }

                $params.Uri = $res._links.next.href 

            } While ( $res._links.next )

            # Link for next time
            $nextLink = $res._links."inx:upcoming".href
            if ( $nextLink ) {
                [void]$script:nextLinks.Add([PSCustomObject]@{
                    name = $objectUrl
                    link = $nextLink
                })
            }
        
            # Go into subobjects, if defined, maybe recursive
            if ( $loadDef.subObjects ) {
                $records | ForEach {
                    $record = $_
                    $subRes = Get-Inxmail -definition $loadDef.subObjects -parentObj $record -extractMode $extractMode
                    try {
                    [void]$inxArr.AddRange( 
                        [System.Collections.ArrayList]@( $subRes )
                    )
                    } catch {
                        "Hallo Welt"
                    }
                }
            }
        }

    }
    
    end {
        
        $inxArr

    }

}

$nextLinks = [System.Collections.ArrayList]@()
$inxObjects = [System.Collections.ArrayList]@()
$inxObjects.AddRange(( Get-Inxmail -definition $loadDefs -extractMode $extractMode ))

$inxObjects | Out-GridView


################################################
#
# PACK TOGETHER RESULTS AND SAVE AS JSON
#
################################################

$session = [PSCustomObject]@{
    timestamp = $extractTimestamp
    nextLinks = $nextLinks
}

# create json object
# weil json-Dateien sind sehr einfach portabel
$json = $session | ConvertTo-Json -Depth 20 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $lastSessionFile -Encoding UTF8






exit 0



    <#

    https://apidocs.inxmail.com/xpro/rest/v1/

    x /list settings not available to read on 2021-06-11
    /mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,types,listIds,readyToSend,embedded}
    /regular-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,sentBefore,types,listIds,readyToSend,mailingStates,embedded},
    /split-test-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds,readyToSend}
    /action-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds}
    /trigger-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds}
    /subscription-mailings{?createdAfter,createdBefore,modifiedAfter,modifiedBefore,sentAfter,listIds,readyToSend}
    /mailings/{mailingId}/approvals
    /mailings/{id}/links{?types}
    /links{?mailingIds,types}
    /sendings{?mailingIds,listIds,sendingsFinishedBeforeDate,sendingsFinishedAfterDate}
    /sendings/{sendingId}/protocol
    /attributes
    /recipients{?attributes,subscribedTo,lastModifiedSince,email,attributes.attributeName,trackingPermissionsForLists,subscriptionDatesForLists,unsubscriptionDatesForLists}
    /test-profiles{?listIds,types,allAttributes}
    /events/subscriptions{?listId,startDate,endDate,types,embedded,recipientAttributes}
    /events/unsubscriptions{?listIds,startDate,endDate,types,embedded,recipientAttributes}
    /imports/recipients/{importId}/files
    /imports/recipients/{importId}/files/{importFileId}/errors
    /bounces{?startDate,endDate,embedded,bounceCategory,listId,mailingId,sendingIds,recipientAttributes}
    /bounces{?startDate,endDate,embedded,bounceCategory,mailingIds,sendingIds,listIds,recipientAttributes}
    /clicks{?sendingId,mailingId,trackedOnly,embedded,startDate,endDate,recipientAttributes,listIds}
    /clicks{?sendingId,trackedOnly,embedded,startDate,endDate,recipientAttributes,mailingIds,listIds}
    /web-beacon-hits{?sendingId,mailingIds,listIds,trackedOnly,embedded,startDate,endDate,recipientAttributes}
    /blacklist-entries{?lastModifiedSince}
    /statistics/responses{?mailingId}
    /statistics/sendings{?mailingId}
    /text-modules{?listId}
    /test-mail-groups
    




    Please note that both request parameters sendingsFinishedBeforeDate and sendingsFinishedAfterDate
    are not recommended to be used for continuous synchronisations. For continuous synchronisation use
    id-based requests to avoid problems of date based synchronization. For this purpose each time you
    reach the last page of a collection you find a link to next page you should request in your next
    scheduled synchronization. A possible problem of date based synchronization could be that most recent
    data is not yet available and would be missed if you request a specific date-time range. For further
    information please read: Long term data synchronization with the upcoming link. https://apidocs.inxmail.com/xpro/rest/v1/#synchronizing

    Long term data synchronization with the upcoming link

    A typical use case is the synchronization of data, where you only want to get new objects in subsequent
    synchronizations. Over longer periods of time, there may be huge amounts of data and the practical way of
    synchronizing is to only look at new data.

    To accommodate this, this API provides a special link on the last page of a collection resource. You can
    save this link and use it as a starting point for a future synchronization. The upcoming link leads to a page
    immediately following your last synchronized page of data. This page will be empty until data is entered into the system.

    Please be aware, new data may not become available instantly upon being entered into the system, as it may be
    stored in write buffers for a while.

    We strongly discourage synchronization based on timestamps for a number of reasons, including write buffers and
    unsynchronized clocks.

    Please also mind, the upcoming link will only return a collection containing new objects, it will not return
    previously retrieved objects, even if they have been changed. If you want to capture all changes to all objects
    of a given type, just get the resource collection of this type.

    If no new data has been entered into the system, following the upcoming link will return an empty collection.

    self            The canonical link to this page.
    first           The link relation for the first page of results.
    next            The link relation for the immediate next page of results.
    inx:upcoming    Links to a possible next page. This next page is only available once further data has been created in the system.






































    $ curl 'https://api.inxmail.com/customer/rest/v1/recipients?lastModifiedSince=2018-01-16T11:42:32Z' -i -X GET
    #>
