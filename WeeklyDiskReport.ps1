#requires -version 5.1

<#
It is assumed this code is being executed with credentials
that have admin rights on the remote computers
#>
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string[]]$Computername,

  [ValidateScript({Test-Path $_})]
  [string]$CSVPath = 'C:\reports\DiskReport.csv'
)

Write-Host "[$(Get-Date)] Starting disk usage job" -ForegroundColor Green
$data = @()

foreach ($computer in $computername) {
  Write-Host "[$(Get-Date)] Processing $computer" -ForegroundColor Yellow
  try {
    $diskInfo = Get-CimInstance -ClassName win32_logicaldisk -Filter 'DriveType=3' -ComputerName $Computer -ErrorAction Stop -ErrorVariable myError
    $data += $diskInfo | Select-Object @{Name = 'Computername'; Expression = { $_.SystemName } },
    DeviceID, Size, Freespace,
    @{Name = 'PercentFree'; Expression = { [math]::Round(($_.freespace / $_.size) * 100, 2) } },
    @{Name = 'DateTime'; Expression = { (Get-Date) } }
  }
  catch {
    Write-Warning "Failed to get disk information from $($computer.ToUpper()). $($_.Exception.Message)"
  }

} #foreach

#write result to pipeline and append to a CSV file
if ($data) {
  Write-Host "[$(Get-Date)] Updating $CSVPath" -ForegroundColor Yellow
  $data | Export-Csv -Path $CSVpath -Append -NoTypeInformation
}

Write-Host "[$(Get-Date)] Job complete!" -ForegroundColor Green
#end of script