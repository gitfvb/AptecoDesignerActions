
################################################
#
# GENERIC CLASSES AND ENUMS
#
################################################


#-----------------------------------------------
# SCOPE
#-----------------------------------------------

enum DSCPScope {
    Global = 0          # global
    Local = 1           # list/local
    Transactional = 2   # Transactional
}


#-----------------------------------------------
# DIGITAL CHANNEL SERVICE PROVIDER
#-----------------------------------------------

class DCSP {

    [String]$providerName
    static [bool]$allowNewFieldCreation = $false

}


#-----------------------------------------------
# FIELDS
#-----------------------------------------------

class DCSPField {

    [String] $id
    [String] $name
    [String] $label
    [String] $description
    [String] $placeholder
    [String] $dataType
    [String[]] $synonyms
    [DSCPScope] $scope = [DSCPScope]::Global
    [bool] $required = $false
    [String[]] $dependency # Dependency to other field
    [DCSPFieldChoice[]] $choices  # For selector values

    # empty default constructor needed to support hashtable constructor
    DCSPField () {
    } 

}

class DCSPFieldChoice {

    [String] $id
    [String] $label
    [String] $description
    
    # empty default constructor needed to support hashtable constructor
    DCSPFieldChoice () {
    } 

}


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# TODO [ ] think again about this class

class DCSPList {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$id
    [String]$name = ""
    [DateTime]$created
    [DateTime]$updated

    hidden [String] $nameConcatChar = " / "
    #hidden [String]$type = " / "


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    DCSPList () {

        $this.init()

    } 
    

    DCSPList ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.id = $stringParts[0].trim()
        $this.name = $stringParts[1].trim()

    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.id, $this.name -join $this.nameConcatChar
    }    

}


#-----------------------------------------------
# MAILINGS - GENERIC
#-----------------------------------------------

# TODO [ ] think again about this class

class DCSPMailing {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$id
    [String]$name = ""
    [DateTime]$created

    hidden [String] $nameConcatChar = " / "
    #hidden [String]$type = " / "


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    DCSPMailing () {

        $this.init()

    } 
    

    DCSPMailing ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.id = $stringParts[0].trim()
        $this.name = $stringParts[1].trim()

    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.id, $this.name -join $this.nameConcatChar
    }    

}


#-----------------------------------------------
# MAILINGS - EMAIL
#-----------------------------------------------

enum DCSPMailingsEmailContentTypes {
    html = 10
    text = 20
}

# Additional properties for email channel
class DCSPMailingsEmail : DCSPMailing {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$subject
    [String]$fromEmail
    [String]$fromName
    [DCSPMailingsEmailContentTypes]$contentType

}


################################################
#
# INHERITED CLASSES AND ENUMS
#
################################################


#-----------------------------------------------
# EMARSYS FIELDS
#-----------------------------------------------

enum EmarsysFieldApplicationTypes {
    shorttext = 0
    longtext = 1
    largetext = 2
    date = 3
    url = 4
    numeric = 5
}

# TODO [ ] implement language code for fields

class EmarsysField : DCSPField {

    hidden [Emarsys]$emarsys
    [bool]$excludeForExport = $false

    EmarsysField () {
        if ( $_.id -in @(27, 28, 29, 32, 33) ) {
            $this.excludeForExport = $true
        }
    } 

    delete() {

        # TODO [ ] check if right

        # Call emarsys
        $params = @{
            cred = $this.emarsys.cred
            uri = "$( $this.emarsys.baseUrl)field/$( $this.id )"
            method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Delete
        }
        $res = Invoke-emarsys @params
        
    }

}


#-----------------------------------------------
# EMARSYS LISTS
#-----------------------------------------------

class EmarsysList : DCSPList {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int] $type
    hidden [Emarsys]$emarsys
    [PSCustomObject]$raw        # the raw source object for this one 


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    EmarsysList () {

        # TODO [ ] needed?
        #$this.init()

    } 

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    # Returns the number of contacts in a contact list.
    [String] count() {

        # Call emarsys
        $params = $this.emarsys.defaultParams + @{
            uri = "$( $this.emarsys.baseUrl)contactlist/$( $this.id )/count"
        }
        [int]$res = Invoke-emarsys @params
        
        return [int]$res
    }    

}

class EmarsysMailing : DCSPMailingsEmail {


    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [Emarsys]$emarsys
    [PSCustomObject]$raw        # the raw source object for this one 
    [String]$language


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    EmarsysMailing () {

        # TODO [ ] needed?
        #$this.init()

    } 

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------


}


#-----------------------------------------------
# EXPORTS
#-----------------------------------------------

class EmarsysExport {


    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [Emarsys]$emarsys
    [PSCustomObject]$raw        # the raw source object for this one 

    [EmarsysField[]]$fields
    [EmarsysList]$list
    [String]$outputFolder

    [int]$exportId

    [String]$status
    [DateTime]$startTime
    [DateTime]$endTime
    #[int]$offset = 0
    hidden [int]$limit = 10000000 #10 #10000000 # TODO [ ] test limit
    [int]$totalSeconds = 0

    hidden [String]$filename
    hidden [String[]]$exportFiles


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    EmarsysExport () {
        $this.init()
    } 

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    hidden [void] init() {
        $this.startTime = [DateTime]::Now
    }

    [String[]] getFiles() {
        return $this.exportFiles
    }

    [void] updateStatus () {

        $params = $this.emarsys.defaultParams + @{
            uri = "$( $this.emarsys.baseUrl )export/$( $this.exportId )"
        }
        $exportStatus = Invoke-emarsys @params
        #Write-Verbose ( $exportStatus | ConvertTo-Json )
        $this.status = $exportStatus.status
        $this.raw = $exportStatus

        if ( $exportStatus.status -eq "done" ) {
            $this.filename = $exportStatus.file_name
            $this.endTime =  [DateTime]::Now
            $t = New-TimeSpan -Start $this.startTime -End $this.endTime
            $this.totalSeconds = $t.TotalSeconds

        }

    }

    [void] autoUpdate() {

        # Create a timer object with a specific interval and a starttime
        $timer = New-Object -Type Timers.Timer
        $timer.Interval  = 10000 # milliseconds, the interval defines how often the event gets fired

        $timerStartTime = Get-Date
        $timerTimeout = 90 # seconds

        # Register an event for every passed interval
        Register-ObjectEvent -InputObject $timer  -EventName "Elapsed" -SourceIdentifier "Timer.Elapsed" -MessageData @{ timeout=$timerTimeout; start = $timerStartTime; emarsysExport = $this } -Action {
            
            # Input variables and objects    
            $currentStart = $Event.MessageData.start
            $timeout = $Event.MessageData.timeout
            $emarsysExport = $Event.MessageData.emarsysExport
            $timer = $Sender

            # Calculate current timespan
            $timeSpan = New-TimeSpan -Start $currentStart -End ( Get-Date )

            # Check current status
            $params = $emarsysExport.emarsys.defaultParams + @{
                uri = "$( $emarsysExport.emarsys.baseUrl )export/$( $emarsysExport.exportId )"
            }
            $exportStatus = Invoke-emarsys @params

            $emarsysExport.status = $exportStatus.status
            $emarsysExport.raw = $exportStatus
    
            if ( $exportStatus.status -eq "done" ) {
                $emarsysExport.filename = $exportStatus.file_name
                $emarsysExport.endTime =  [DateTime]::Now
                $t = New-TimeSpan -Start $this.startTime -End $this.endTime
                $emarsysExport.totalSeconds = $t.TotalSeconds
                $timer.Stop()
            }

            # Is timeout reached? Do something!
            
            if ( $timeSpan.TotalSeconds -gt $timeout ) {

                # Stop timer now (it is important to do this before the next processes run)
                $timer.Stop()
                Write-Host "Done! Timer stopped!"
                Write-Log -message "Done! Timer stopped!"

            }
            
            # Output the results to console
            #Write-Host -NoNewLine "`r$( $timeSpan.TotalSeconds )/$( $timeout )"
            #[System.Console]::Write($timeSpan.Seconds)

        } | Out-Null

        # Start the timer
        $timer.Start()

    }

    [void] downloadResult([String]$outputFolder) {

        # Download file
        # TODO [ ] implement offset and limit
        # TODO [ ] export contains multiple files
        # TODO [ ] calculate time when finishing export
        if ( $this.status -eq "done" ) {

            $listCount = $this.list.count()
            $rounds = [Math]::Ceiling($listCount/$this.limit)

            for ( $i = 0 ; $i -lt $rounds ; $i++ ) {
                $offset = $i * $rounds
                $params = $this.emarsys.defaultParams + @{
                    uri = "$( $this.emarsys.baseUrl )export/$( $this.exportId )/data?offset=$( $offset )&limit=$( $this.limit )"
                    outFile = "$( $outputFolder )\$( $this.filename )"
                }
                Invoke-emarsys @params
                $this.exportFiles += $params.OutFile
            }

        }
        
    }

}


################################################
#
# MAIN CLASS
#
################################################


class Emarsys : DCSP {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [pscredential]$cred                 # holds the username and secret
    hidden [int]$waitSeconds = 10 
    [String]$baseUrl = "https://api.emarsys.net/api/v2/"
    [DSCPScope[]]$supportedScopes = @(
        [DSCPScope]::Global
        #[DSCPScope]::Local
    )
    
    # Override inherited properties
    [String]$providerName = "emarsys"
    static [bool]$allowNewFieldCreation = $true

    [PSCustomObject]$defaultParams
    hidden [EmarsysExport[]]$exports


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------


    # empty default constructor needed to support hashtable constructor
    Emarsys () {
        $this.init()
    } 

    Emarsys ( [String]$username, [String]$secret ) {        
        $this.init( $username, $secret )
    }

    Emarsys ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.init( $username, $secret, $baseUrl)
    }

    Emarsys ( [pscredential]$cred ) {
        $this.init( $cred )
    }

    Emarsys ( [pscredential]$cred, [String]$baseUrl ) {
        $this.init( $cred, $baseUrl )
    }

    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------

    hidden [void] init () {

        $this.defaultParams = @{
            cred = $this.cred
        }

        if ( $script:settings.download.waitSecondsLoop ) {
            $this.waitSeconds = $script:settings.download.waitSecondsLoop
        }

        #$this.exports = [System.Collections.ArrayList]@()

    }

    hidden [void] init ( [String]$username, [String]$secret ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $username, $stringSecure )
        $this.init()
    }

    hidden [void] init ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $username, $secret )
    }

    hidden [void] init ( [pscredential]$cred ) {
        $this.cred = $cred
        $this.init()
    }

    hidden [void] init ( [pscredential]$cred, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $cred )
    }



    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [PSCustomObject] getSettings () {

        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)settings"
        }

        $res = Invoke-emarsys @params
        return $res
  
    }

    [string] newField([String]$fieldname, [EmarsysFieldApplicationTypes]$dataType) {

        # TODO [] implement this one https://dev.emarsys.com/v2/fields/create-a-field

        $body = @{
            name = $fieldname
            application_type = $dataType # shorttext|longtext|largetext|date|url|numeric
            #string_id = "" # optional otherwise autogenerated
        }
        $bodyJson = ConvertTo-Json -InputObject $body -Depth 20

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)field"
            method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
            $body = $bodyJson
            verbose = $true
        }
        $res = Invoke-emarsys @params

        # return the new identifier of the field
        return $res

    }

    [PSCustomObject] getFields () {
        return getFields -loadDetails $true
    }



    [EmarsysField[]] getFields ([bool]$loadDetails) {

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)field"
        }
        $res = Invoke-emarsys @params
        

        # Transform result to objects
        $fields = [System.Collections.ArrayList]@()
        $res | ForEach {

            $f = $_
            
            $choice = [System.Collections.ArrayList]@()

            if ( $loadDetails ) {

                # list fields choices
                if ( $f.application_type -eq "singlechoice") {
                    $params = @{
                        cred = $this.cred
                        uri = "$( $this.baseUrl)field/$( $f.id )/choice"
                    }
                    $choices = Invoke-emarsys @params
                    $choices | ForEach {
                        $c = $_
                        [void]$choice.Add([DCSPFieldChoice]@{
                            "id" = $c.id
                            "label" = $c.choice
                        })
                    }
                    # TODO [ ] check bit_position in return data
                }

                # TODO [ ] check multiple choice which is called with /choices
                
            }

            $fields.Add([EmarsysField]@{
                "emarsys" = $this
                "id" = $f.id
                "name" = $f.string_id
                "label" = $f.name
                "dataType" = $f.application_type
                #"scope" = [DSCPScope]::Global
                "choices" = $choice
            })

            $choice.Clear()

        }



        # Return the results
        return $fields
               
    }

    [EmarsysList[]] getLists () {

        # https://dev.emarsys.com/v2/contact-lists/count-contacts-in-a-contact-list
        # TODO  [ ] implement as classes with create, rename, delete, count, list contacts, list contacts data, add contacts, lookup(?)

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)contactlist"
        }
        $res = Invoke-emarsys @params


        # Transform result to objects
        $lists = [System.Collections.ArrayList]@()
        $res | ForEach {

            $l = $_
            
            [void]$lists.Add([EmarsysList]@{
                "emarsys" = $this
                "id" = $l.id
                "name" = $l.name
                "created" = $l.created
                "type" = $l.type
                "raw" = $l
            })

        }

        return $lists

    }

    [PSCustomObject] getSources () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)source"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [EmarsysMailing[]] getEmailCampaigns () {

        # https://dev.emarsys.com/v2/contact-lists/count-contacts-in-a-contact-list
        # TODO  [ ] implement as classes with the toString-function, list tracked links, list sections, preview

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)email"
        }
        $res = Invoke-emarsys @params

        # Transform result to objects
        $campaigns = [System.Collections.ArrayList]@()
        $res | ForEach {

            $c = $_
            
            [void]$campaigns.Add([EmarsysMailing]@{
                
                "id" = $c.id
                "name" = $c.name
                "created" = $c.created

                "subject" = $c.subject
                "fromEmail" = $c.fromemail
                "fromName" = $c.fromname
                "contentType" = [DCSPMailingsEmailContentTypes]::($c."content_type")

                "language" = $c.language
                "emarsys" = $this
                "raw" = $c

            })

        }

        return $campaigns

    }

    # TODO [ ] implement media database if needed

    [PSCustomObject] getConditionalTextRules () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)condition"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [PSCustomObject] getEmailTemplates () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)email/templates"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [PSCustomObject] getLinkCategories () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)settings/linkcategories"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [PSCustomObject] getExternalEvents () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)event"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [PSCustomObject] getAutomationCenterPrograms () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)ac/programs"
        }
        $res = Invoke-emarsys @params
        return $res

    }

    [PSCustomObject] getAutoImportProfiles () {

        # TODO  [ ] implement as classes 

        # Call emarsys
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)settings/autoimports"
        }
        $res = Invoke-emarsys @params
        return $res

    }



    [EmarsysExport[]] downloadContactListSync ( [EmarsysList]$list, [String]$outputFolder ) {
        
        $exportJobs = [System.Collections.ArrayList]@()

        # split the fields automatically
        # TODO [ ] find out if the primary key is always included

        $fields = $this.getFields() | where { $_.excludeForExport -eq $false }
        
        # paging through fields and create exports
        $count = $fields.count
        $maxFields = 20 # max from emarsys
        $rounds = [System.Math]::Ceiling($count/$maxFields)
        for ( $i = 0 ; $i -lt $rounds ; $i++ ) {
            $start = $i * $maxFields
            $end = ( ( $i + 1 ) * $maxFields ) -1
            $exportFields = $fields[$start..$end]
            $emarsysExport = $this.downloadContactListSync($list,$exportFields,$outputFolder) 
            $exportJobs.Add( $emarsysExport )
            $this.exports += $emarsysExport
        }

        #$this.exports.AddRange($exportJobs)

        return $exportJobs

    }

    [EmarsysExport[]] getExports() {
        return $this.exports
    }

    # Download the contacts synchronously
    [EmarsysExport] downloadContactListSync ( [EmarsysList]$list, [EmarsysField[]]$fields, [String]$outputFolder ) {

        # TODO [ ] implement as classes 
        # TODO [ ] make delimiter available as enum
        # TODO [ ] implement language

        $exportFields = $fields | where { $_.excludeForExport -eq $false }

        # Create export
        $body = @{
            distribution_method = "local"
            contactlist = $list.id
            contact_fields = $exportFields.id # # field ids -> max 20 columns, exclude of 27, 28, 29, 32 and 33
            delimiter = ";" # ,|;
            add_field_names_header = 1
            #language = "de"
        }

        # Call emarsys to create export job
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl )email/getcontacts"
            method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
            body = ConvertTo-Json -InputObject $body -Depth 20
        }
        $exportId = Invoke-emarsys @params        

        # Create the export object now
        $export = ( [EmarsysExport]@{
            
            "emarsys" = $this
            "raw" = $exportId
        
            "fields" = $fields
            "list" = $list
        
            "exportId" = $exportId.id
        
            #[DateTime]$startTime
            #[DateTime]$endTime

        })

        $this.exports += $export

        return $export
<#
        # Check export status
        $finish = $false
        $filename = ""
        Do {
            Start-Sleep -Seconds $this.waitSeconds
            $params = $this.defaultParams + @{
                uri = "$( $this.baseUrl)export/$( $exportId.id )"
            }
            $exportStatus = Invoke-emarsys @params
            if ( $exportStatus.status -eq "done" ) {
                $finish = $true
                $filename = $exportStatus.file_name
            }
        } Until ( $finish )

        # Download file
        # TODO [ ] implement offset and limit
        # TODO [ ] export contains multiple files
        # TODO [ ] calculate time when finishing export
        $offset = 0
        $limit = 10000000
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)export/$( $exportId.id )/data?offset=$( $offset )&limit=$( $limit )"
            OutFile = "$( $outputFolder )\$( $filename )"
        }
        $exportFile = Invoke-emarsys @params
        
        return $params.OutFile
#>
    }

    [void] downloadContactListAsync ([EmarsysList]$list, [EmarsysField[]]$fields) {
        
        # TODO  [ ] implement asynchronous way with automated updating of export status

    }

    [String] downloadResponses ([EmarsysList]$list) {

        # TODO [ ] implement the response download

        # https://dev.emarsys.com/v2/contact-and-email-data/export-responses
        $body = @{
            distribution_method = "local"
            time_range = @()
            contact_fields = @()
            sources = @()
            analysis_fields = @()

            # optional
            email_id = 0
            contactlist = $list.id
            delimiter = ";" # ,|;
            add_field_names_header = 1
            #language = "de"
        }

        return ""

    }


}


################################################
#
# OTHER FUNCTIONS
#
################################################

function Invoke-emarsys {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$false)][pscredential]$cred                                   # securestring containing username as user and secret as password
        ,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://api.emarsys.net/api/v2/"  # default url to use
        ,[Parameter(Mandatory=$false)][Microsoft.PowerShell.Commands.WebRequestMethod]$method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        ,[Parameter(Mandatory=$false)][String]$outFile = ""
        ,[Parameter(Mandatory=$false)][System.Object]$body = $null
    )

    begin {
        

        #-----------------------------------------------
        # AUTH
        #-----------------------------------------------

        <#

        example for header

        X-WSSE: UsernameToken
        Username="customer001",
        PasswordDigest="ZmI2ZmQ0MDIxYmQwNjcxNDkxY2RjNDNiMWExNjFkZA==",
        Nonce="d36e316282959a9ed4c89851497a717f",
        Created="2014-03-20T12:51:45Z"

        source: https://dev.emarsys.com/v2/before-you-start/authentication
        api endpoints: https://trunk-int.s.emarsys.com/api-demo/#tab-customer

        other urls
        https://dev.emarsys.com/v2/emarsys-developer-hub/what-is-the-emarsys-api
        #>

        # Extract credentials
        $secret = $cred.GetNetworkCredential().Password
        $username = $cred.UserName

        # Create nonce
        $randomStringAsHex = Get-RandomString -length 16 | Format-Hex
        $nonce = Get-StringfromByte -byteArray $randomStringAsHex.Bytes
        
        # Format date
        $date = [datetime]::UtcNow.ToString("o")

        # Create password digest
        $stringToSign = $nonce + $date + $secret
        $sha1 = Get-StringHash -inputString $stringToSign -hashName "SHA1"
        $passwordDigest = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($sha1))

        # Combine Escher XWSSE header
        $xwsseArr = [System.Collections.ArrayList]@()
        [void]$xwsseArr.Add("UsernameToken Username=""$( $username )""")
        [void]$xwsseArr.Add("PasswordDigest=""$( $passwordDigest )""")
        [void]$xwsseArr.Add("Nonce=""$( $nonce )""")
        [void]$xwsseArr.Add("Created=""$( $date )""")

        # Setup content type
        $contentType = "application/json;charset=utf-8"
        #$xwsseArr.Add("Content-type=""$( $contentType )""") # take this out possibly
        
        # Join Escher XWSSE together
        $xwsse = $xwsseArr -join ", "  
        #$xwsse


        #-----------------------------------------------
        # HEADER
        #-----------------------------------------------

        $header = @{
            "X-WSSE"=$xwsse
            "X-Requested-With"=	"XMLHttpRequest"
        }

    }
    
    process {
        
                
        $params = @{
            "Uri" = $uri
            "Method" = $method
            "Headers" = $header
            "ContentType" = $contentType
            "Verbose" = $true
        }

        if ( $body -ne $null ) {
            $params += @{
                "Body" = $body
            }
        }

        if ( $outFile -ne "" ) {
            $params += @{
                "OutFile" = $outFile
            }
        }

        $result = Invoke-RestMethod @params

    }
    
    end {
        
        if ( $outFile -ne "" ) {

            $outFile

        } else {

            if ( $result.replyCode -eq 0 <# -and $result.replyText -eq "OK" #> ) {

                $result.data
    
            } else {
                # Errors see here: https://dev.emarsys.com/v2/response-codes/http-400-errors
                Write-Log -message "Got back $( $result.replyText ) from call to url $( $uri ), throwing exception"
                throw [System.IO.InvalidDataException]
                
            }
    
        }

    }

}