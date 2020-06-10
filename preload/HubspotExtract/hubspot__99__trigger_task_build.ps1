<#

https://www.windowspro.de/script/geplante-aufgaben-anzeigen-starten-anhalten-deaktivieren-powershell

#>

Get-ScheduledTask -TaskPath \ -CimSession
#Get-ScheduledTask | ? state -eq Disabled
#Get-ScheduledTask -TaskPath \Microsoft\Windows\Win*
#Get-ScheduledTask StartComponentCleanup | Get-ScheduledTaskInfo
#Start-ScheduledTask