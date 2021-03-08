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
