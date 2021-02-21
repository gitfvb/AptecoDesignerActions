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
	    Password= "def"
        scriptPath = "C:\Users\Florian\Documents\GitHub\AptecoDesignerActions\preload\emarsysExtract"
	    abc= "def"
	    Username= "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://dev.emarsys.com/v2/first-steps/1-prerequisites

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
$moduleName = "EMARSYSMAILINGS"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
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
# FUNCTIONS
#
################################################

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
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################




#$settingsLoad = Invoke-RestMethod @params

$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.secret ) -AsPlainText -Force
$cred = [pscredential]::new( $settings.login.username, $stringSecure )
[Emarsys]::allowNewFieldCreation
$emarsys = [Emarsys]::new($cred,$settings.base)
$emarsys.getSettings()
$f = $emarsys.getFields()
$f | Out-GridView

exit 0
$emarsys.getEmailCampaigns()
$emarsys.getAutomationCenterPrograms()
$emarsys.getEmailTemplates()
$emarsys.getExternalEvents()
$emarsys.getLinkCategories()
$emarsys.getLists()
$emarsys.getSources()
$emarsys.getAutoImportProfiles()
$emarsys.getConditionalTextRules()


#Invoke-emarsys -uri "$( $settings.base )settings" -cred $cred



#-----------------------------------------------
# FIELDS
#-----------------------------------------------

$url = "$( $settings.base )field/translate/de"
Invoke-emarsys -uri "$( $settings.base )field/translate/de"


$fields = Invoke-RestMethod -uri $url -Method Get -Headers $header -ContentType $contentType -Verbose
$fields.data | Out-GridView

exit 0

#-----------------------------------------------
# CAMPAIGNS
#-----------------------------------------------

$url = "https://trunk-int.s.emarsys.com/api/v2/email"
$campaigns = Invoke-RestMethod -uri $url -Method Get -Headers $header -Verbose
$selectedCampaigns = $campaigns.data | Out-GridView -PassThru


#-----------------------------------------------
# PREVIEW
#-----------------------------------------------

$selectedCampaigns | ForEach {
    $id = $_.id 
    $url = "https://trunk-int.s.emarsys.com/api/v2/email/$( $id )/preview"
    $preview = Invoke-RestMethod -uri $url -Method Post -Headers $header -Verbose -Body "{""version"": ""html""}"
    $preview.data
}

exit 0

#-----------------------------------------------
# LOAD TEMPLATES
#-----------------------------------------------

$templates = Get-eLetterTemplates


#-----------------------------------------------
# BUILD MAILING OBJECTS
#-----------------------------------------------

$mailings = @()
$templates | foreach {

    # Load data
    $template = $_
    #$id = Get-StringHash -inputString $template.url -hashName "MD5" #-uppercase

    # Create mailing objects
    $mailings += [Mailing]@{mailingId=$template.hashid;mailingName=$template.name}

}

$messages = $mailings | Select @{name="id";expression={ $_.mailingId }}, @{name="name";expression={ $_.toString() }}


#-----------------------------------------------
# GET MAILINGS DETAILS
#-----------------------------------------------
<#
# The way without classes
$messages = $result | where { $_.state -in $settings.mailings.states } | Select-Object @{name="id";expression={ $_.'_id' }},
                                            @{name="name";expression={ "$( $_.'_id' )$( $settings.nameConcatChar )$( $_.name )"}} #$( if ($_.Description -ne '') { $settings.nameConcatChar } )$( $_.Description )" }}

#>


################################################
#
# RETURN
#
################################################

# real messages
return $messages


