#requires -version 7.6
#requires -RunAsAdministrator

<#
This may not necessarily be the fastest or best way to get this information,
but it demonstrates using a PowerShell 7 feature in a script file.
#>
Param([string]$LogName = "*")

Get-WinEvent -listLog $LogName | Where RecordCount -gt 0 |
Foreach-Object -parallel {
    Select-Object -InputObject $_ -property LogName,RecordCount,LogMode,
    @{Name = "SizeKB";Expression = {$_.FileSize/1kb -as [int]}},
    @{Name = "FileSizeKB";Expression = {$_.MaximumSizeInBytes/1kb -as [int]}},
    @{Name = "PctUsed"; Expression = { [math]::Round(($_.FileSize/$_.MaximumSizeInBytes)*100,2) }},
    LastWriteTime,IsEnabled,
    @{Name = "Computername";Expression = { $env:COMPUTERNAME}}
}