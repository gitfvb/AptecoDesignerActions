# General

* Download this script and put it in your build folder in a subfolder named `postextract`
* Create a environment variable in Designer named `BUILDDIR`

# Example 1

* The script code is in this folder, but it looks like this

```PowerShell
Write-Host "---------------------"
$env = [Environment]::GetEnvironmentVariables()
ForEach ( $key in $env.Keys ) { 
    $valueString = "$( $key ) = $( $env.$key )"
    Write-Host  "`t$( $valueString )"
    $valueString >> "$( $Env:BUILDDIR )\environment_variables.txt"
 }
Write-Host "---------------------"
```

* Set your PowerShell script in Designer like:<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/110300467-2fc4ac00-7ff7-11eb-8c06-9a80b0c73955.png)
* Execute your build and you should see something like:<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/110300785-99dd5100-7ff7-11eb-8784-21bcc2972997.png)

# Example 2

* The script code is in this folder, but it looks like this

```PowerShell
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

```

* Set your PowerShell script in Designer like:<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/110305772-5554b400-7ffd-11eb-9a83-29ffdce534a7.png)
* Execute your build and you should see something like:<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/110305624-2dfde700-7ffd-11eb-9891-4a2b7c83f595.png)
