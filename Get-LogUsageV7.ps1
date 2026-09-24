#requires -version 7.6
#requires -RunAsAdministrator

<#
This may not necessarily be the fastest or best way to get and display this information,
but it demonstrates using PowerShell 7 features in a script file.
#>

param([string]$LogName = '*')

Get-WinEvent -ListLog $LogName | Where-Object RecordCount -gt 0 |
Select-Object -Property LogName, RecordCount, LogMode,
@{Name = 'SizeKB'; Expression = { $_.FileSize / 1kb -as [int] }},
@{Name = 'FileSizeKB'; Expression = { $_.MaximumSizeInBytes / 1kb -as [int] }},
@{Name = 'PctUsed'; Expression = {
    #[math]::Round(($_.FileSize/$_.MaximumSizeInBytes)*100,2)
    $value = $_.FileSize / $_.MaximumSizeInBytes
    #treat the percentage as a string
    $p = '{0:p2}' -f $value
    #show in red if 95% or higher
    ($value -ge .95) ? "$($PSStyle.Foreground.BrightRed)$p$($PSStyle.Reset)" : $p
}},
LastWriteTime, IsEnabled,@{Name = 'Computername'; Expression = { $env:COMPUTERNAME }}