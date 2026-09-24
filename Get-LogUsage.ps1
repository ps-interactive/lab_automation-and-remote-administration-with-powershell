#requires -version 5.1
#requires -RunAsAdministrator

Param([string]$LogName = "*")

Get-WinEvent -listLog $LogName | Where-Object RecordCount -gt 0 |
Select-Object -property LogName,RecordCount,LogMode,
@{Name = "SizeKB";Expression = {$_.FileSize/1kb -as [int]}},
@{Name = "FileSizeKB";Expression = {$_.MaximumSizeInBytes/1kb -as [int]}},
@{Name = "PctUsed"; Expression = {[math]::Round(($_.FileSize/$_.MaximumSizeInBytes)*100,2)}},
LastWriteTime,IsEnabled,
@{Name = "Computername";Expression = {$env:COMPUTERNAME}}