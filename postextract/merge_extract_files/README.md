
The files have to be in the end `utf8NoBOM`, so it is neccessary to install PowerShell 7 (`pwsh.exe`) to support this by using Get-Content and Set-Content.

To use these scripts, please put the scripts with `Run command` and following settings into Designer:

Script | Step | Command | Arguments | Output | Parameters
-|-|-|-|-|-
`00__create_settings__postextract.ps1` | Pre Load Actions |`pwsh.exe`|` -file ".\postextract\merge_extract_files\00__create_settings__postextract.ps1"`| [x] Redirect output to progress log|[ ] System Name<br/>[ ] Revision Number<br/>[ ] Linked System Name
`10__merge_files__postextract.ps1` | Post extract command |`pwsh.exe`|` -file ".\postextract\merge_extract_files\00__create_settings__postextract.ps1"`
`20__revert_incremental_delta.ps1` | Pre Load Actions |`pwsh.exe`|` -file ".\postextract\merge_extract_files\20__revert_incremental_delta.ps1"`| [x] Redirect output to progress log|[ ] System Name<br/>[ ] Revision Number<br/>[ ] Linked System Name

