#requires -version 5.1

#configure event log size
#all parameters are mandatory
#this script file is intended to be run remotely using Invoke-Command
Param(
    [Parameter(Mandatory)]
    [string]$LogName,
    [Parameter(
        Mandatory,
        HelpMessage = "Enter a value between 64KB and 4GB. The value must be divisible by 64KB"
    )]
    [int64]$MaximumSize,
    [ValidateSet("Circular","Retain","AutoBackup")]
    [string]$LogMode = "Circular"
)

Try {
    $log = Get-WinEvent -ListLog $LogName -ErrorAction Stop
    if ($log) {
        $log.MaximumSizeInBytes = $MaximumSize
        $log.LogMode = $LogMode
        $log.SaveChanges()
    }
    Get-WinEvent -ListLog $LogName
}
Catch {
    Write-Warning "[$($env:computername)] Failed to configure the specified event log, $LogName. $($_.Exception.Message)" -ErrorAction Stop
}