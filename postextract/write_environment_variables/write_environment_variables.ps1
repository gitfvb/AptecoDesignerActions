Write-Host "---------------------"
$env = [Environment]::GetEnvironmentVariables()
ForEach ( $key in $env.Keys ) { 
    $valueString = "$( $key ) = $( $env.$key )"
    Write-Host  "`t$( $valueString )"
    $valueString >> "$( $Env:BUILDDIR )\environment_variables.txt"
 }
Write-Host "---------------------"
