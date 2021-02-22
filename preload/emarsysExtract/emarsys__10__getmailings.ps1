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

# Read static attribute
[Emarsys]::allowNewFieldCreation

# Create emarsys object
$emarsys = [Emarsys]::new($cred,$settings.base)


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

# Read settings
$emarsys.getSettings()


#-----------------------------------------------
# EXPORT
#-----------------------------------------------

$lists = $emarsys.getLists()
$selectedlist = ( $lists | Select *,  @{name="count";expression={ $_.count() }} -exclude raw ) | Out-GridView -PassThru | Select -first 1
$list = $lists | where { $_.id -eq $selectedlist.id }
$fields = $emarsys.getFields($false) | Out-GridView -PassThru | Select -first 20
$t = Measure-Command {
    $emarsys.downloadContactListSync($list,$fields,".")
}
"Downloaded in $( $t.TotalSeconds ) seconds"

exit 0


#-----------------------------------------------
# FIELDS
#-----------------------------------------------

# Read fields without details
$f = $emarsys.getFields($false)
$f | ft

# Read fields with details
$f = $emarsys.getFields($true)
$f | Out-GridView


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# Test the change of the concat character for lists and messages
$settings.nameConcatChar = " | "

# Load lists
$lists = $emarsys.getLists()

# Show lists blank
$lists | ft

# Show lists with toString
$lists | Select *, @{name="toString";expression={ $_.toString() }} -exclude raw | ft

# Show lists with counts
( $lists | Select *,  @{name="count";expression={ $_.count() }} -exclude raw )| ft


#-----------------------------------------------
# MAILINGS
#-----------------------------------------------

# Get Mailings
$mailings = $emarsys.getEmailCampaigns()

# Show mailings
$mailings | select * -exclude raw | ft

# Get Mailings with toString
$mailings | Select id, name, @{name="toString";expression={ $_.toString() }} | ft



exit 0

# Other calls


$emarsys.getEmailTemplates() 
$emarsys.getAutomationCenterPrograms()
$emarsys.getExternalEvents()
$emarsys.getLinkCategories()
$emarsys.getSources()
$emarsys.getAutoImportProfiles()
$emarsys.getConditionalTextRules()


#Invoke-emarsys -uri "$( $settings.base )settings" -cred $cred



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

