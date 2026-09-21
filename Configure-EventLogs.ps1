#requires -version 5.1

#configure event log size and mode
#this script file is intended to be run remotely using Invoke-Command.

param(
    [Parameter(Mandatory)]
    [string[]]$LogName,
    [Parameter(
        Mandatory,
        HelpMessage = 'Enter a value between 64KB and 4GB. The value must be divisible by 64KB'
    )]
    [int64]$MaximumSize,
    [ValidateSet('Circular', 'Retain', 'AutoBackup')]
    [string]$LogMode = 'Circular',
    [switch]$Passthru
)

foreach ($logItem in $logName) {
    try {
        $log = Get-WinEvent -ListLog $logItem -ErrorAction Stop
        if ($log) {
            $log.MaximumSizeInBytes = $MaximumSize
            $log.LogMode = $LogMode
            $log.SaveChanges()
        }
        if ($Passthru) {
            Get-WinEvent -ListLog $LogItem |
            Select-Object LogName, MaximumSizeInBytes, LogMode,
            @{Name = 'Computername'; Expression = { $env:COMPUTERNAME }}
        }
    }
    catch {
        Write-Warning "[$($env:computername)] Failed to configure the specified event log, $LogName. $($_.Exception.Message)" -ErrorAction Stop
    }
}