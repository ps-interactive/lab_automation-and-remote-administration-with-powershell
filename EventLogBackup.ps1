#requires -version 5.1
#requires -RunAsAdministrator

<#
Backup and clear classic event logs to a local folder.
Each log will be backed to a file named YYYYMMDD_computername_LogName.evt.
#>

#Remoting usage:
#Invoke-Command -FilePath .\EventLogBackup.ps1 -ArgumentList @(,@(,'system','application','windows powershell')) -ComputerName SRV1

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$LogName,

    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath = 'C:\LogBackup',

    [ValidateSet('BackupOnly', 'BackupAndClear', 'ClearOnly')]
    [string]$Action = 'BackupAndClear'
)

Write-Host "[$($env:Computername) $(Get-Date -Format g)] Starting EventLogBackup" -ForegroundColor Green

if (-not (Test-Path $DestinationPath)) {
    Write-Host "[$($env:Computername) $(Get-Date -Format g)] Creating $DestinationPath" -ForegroundColor Magenta
    try {
        New-Item $DestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Failed to created $DestinationPath . $($_.Exception.Message)"
        Write-Host "[$($env:Computername) $(Get-Date -Format g)] Ending EventLogBackup" -ForegroundColor Green
        #Bail out
        return
    }
}
foreach ($log in $LogName) {
    try {
        Write-Host "[$($env:Computername) $(Get-Date -Format g)] Validating log $($Log.ToUpper())" -ForegroundColor Yellow
        $logFile = Get-CimInstance -ClassName Win32_NTEventlogFile -Filter "LogFileName='$log'" -ErrorAction Stop
    }
    catch {
        Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Failed to find $log"
    }
    if ((Test-Path $logFile.Name) -and ($Action -match 'Backup')) {
        $backupFile = '{0}_{1}_{2}.{3}' -f (Get-Date -Format yyyyMMdd), $env:COMPUTERNAME, $LogFile.LogFileName.replace(' ', '-'), $logFile.Extension
        $backupTarget = Join-Path -Path $DestinationPath -ChildPath $backupFile
    }

    if ($Action -match 'Backup') {
        Write-Host "[$($env:Computername) $(Get-Date -Format g)] Backing up $($logFile.Name) to $backupTarget" -ForegroundColor DarkCyan
        $rc = $logFile | Invoke-CimMethod -MethodName BackupEventLog -Arguments @{ArchiveFileName = $backupTarget }
        $name = $logFile.LogFileName.ToUpper()
        switch ($rc.ReturnValue) {
            0 {
                #success
                Write-Host "[$($env:Computername) $(Get-Date -Format g)] Backup successful." -foreground Green
            } #end 0
            3 {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Backup failed for $name. Verify $DestinationPath is accessible"
            }
            5 {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Backup failed for $name. There is likely a permission or delegation problem."
            }
            8 {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Backup failed for $name. You are likely missing a privilege."
            }
            80 {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Backup failed for $name. A backup file already exists."
            }
            183 {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Backup failed for $name. A file with the same name already exists."
            }
            default {
                Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Unknown Error backing up $name! Return code $($rc.ReturnValue)"
            }
        }#end switch
    }

    if ($Action -match 'Clear') {
        Write-Host "[$($env:Computername) $(Get-Date -Format g)] Clearing $($logFile.Name) " -ForegroundColor Red
        $rc = $logFile | Invoke-CimMethod -MethodName ClearEventLog
        if ($rc.ReturnValue -eq 0) {
            Write-Host "[$($env:Computername) $(Get-Date -Format g)] Event log cleared" -foreground Green
        }
        else {
            Write-Warning "[$($env:Computername) $(Get-Date -Format g)] Failed to clear event log. Return code $($rc.ReturnValue)"
        }
    }
} #foreach

Write-Host "[$($env:Computername) $(Get-Date -Format g)] Ending EventLogBackup" -ForegroundColor Green