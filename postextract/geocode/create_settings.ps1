$extractInfos = Get-Childitem -Path "C:\Apteco\Build\20210308\extract" -Filter "*.info.xml"

$extracts = [System.Collections.ArrayList]@()
$extractInfos | ForEach {
    $f = $_
    $c = Get-Content -Path $f.FullName -Encoding UTF8 -Raw
    $x = [xml]$c
    [void]$extracts.Add($x.ExtractFileSummary)
}

# Choose your tables
$chosenExtracts = $extracts.Table | Out-GridView -PassThru

# Choose your fields for tables
$extractDefinitions = [System.Collections.ArrayList]@()
$chosenExtracts | ForEach {
    $e = $_
    $extract = $extracts.where({ $_.Table -eq $e })
    $fields = $extract.Fields.string
    $referenceField = $fields | Out-GridView -PassThru | select -first 1
    $addressFields = $fields | Out-GridView -PassThru
    [void]$extractDefinitions.Add(@{
        "name" = $e
        #"filename" = $extract.Filename
        #"encoding" = $extract.Encoding
        "reference" = $referenceField
        "addressFields" = $addressFields
    })
}
