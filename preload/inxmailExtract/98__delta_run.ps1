if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location $scriptPath

$params = [Hashtable]@{
    method = "delta"
    scriptPath = $scriptPath
}

. ".\20__extract_objects.ps1" -params $params