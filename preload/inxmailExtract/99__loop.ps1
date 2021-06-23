if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

#$scriptPath = "D:\FastStats\Build\Inxmail\preload\inxmailExtract"
Set-Location $scriptPath

$i = 1
Do {

    if ( $i % 720 -eq 0 ) {
        
        $params = [Hashtable]@{
            method = "daily"
            scriptPath = $scriptPath
        }
        
        $i = 1

    } elseif ( $i % 15 -eq 0 ) {
        
        $params = [Hashtable]@{
            method = "full"
            scriptPath = $scriptPath
        }

        $i += 1

        
    } else {

        $params = [Hashtable]@{
            method = "delta"
            scriptPath = $scriptPath
        }

        $i += 1
    }

    . ".\20__extract_objects.ps1" -params $params

    Start-Sleep -Seconds 120

} While (1 -eq 1)