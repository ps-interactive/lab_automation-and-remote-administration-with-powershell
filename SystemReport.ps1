#requires -version 5.1

<#
This script uses advances techniques with ConvertTo-Html to create
an HTML report of system information from multiple computers.
Each computer will have a separate HTML report saved to the specified
directory.
The HTML file will include an embedded CSS style sheet.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0,HelpMessage = "Specify a comma-separated list of computer names.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [Parameter(HelpMessage = "Specify an alternate credential to be used with all computers.")]
    [ValidateNotNullOrEmpty()]
    [PSCredential]$Credential,

    [Parameter(HelpMessage = "Specify the top number of processes by working set size between 1 and 100")]
    [ValidateRange(1,100)]
    [int]$ProcessCount = 20,

    [Parameter(HelpMessage = "Specify the path to a CSS file.")]
    [ValidateScript({Test-Path -path $_})]
    [ValidatePattern('\.css$')]
    [string]$CSSPath = '.\Alternating.css',

    [Parameter(HelpMessage = "Specify the report title.")]
    [ValidateNotNullOrEmpty()]
    [string]$ReportTitle = 'System Status Report',

    [Parameter(HelpMessage = "Specify the output directory.")]
    [ValidateScript({Test-Path -path $_})]
    [string]$ReportPath = 'C:\temp',

    [Parameter(HelpMessage = "Write the HTML file object to the pipeline")]
    [switch]$Passthru
)

#define an internal script version number
$ver = "1.7.2"

#region Setup
Clear-Host

Write-Verbose "[$((Get-Date).TimeOfDay)] Starting $($MyInvocation.MyCommand.Source) v$ver"
Write-Verbose "[$((Get-Date).TimeOfDay)] Running under PowerShell v$($PSVersionTable.PSVersion)"

#use the same report date for all computers
$rptDate = Get-Date
Write-Verbose "[$((Get-Date).TimeOfDay)] Using report date of $rptDate"

#initialize a generic list for all jobs
Write-Verbose "[$((Get-Date).TimeOfDay)] Initializing job list"
$jobs = [System.Collections.Generic.List[object]]::new()

#a list of critical services to check on all computers
$svcList = 'WinMgmt', 'RemoteRegistry', 'NetLogon', 'LanmanServer', 'EventLog', 'gpsvc', 'mpssvc', 'termservice', 'w32time', 'wuauserv', 'dns', 'adws', 'kdc'

#define the script block that will be run remotely on all computers
$sb = {
    #operating system
    $cimOS = Get-CimInstance -ClassName Win32_OperatingSystem

    $cimOS | Select-Object -Property @{Name = 'Computername'; Expression = { $_.CSName } },
    @{Name = 'OSName'; Expression = { $_.Caption } }, Version,
    @{Name = 'Architecture' ; Expression = { $_.OSArchitecture } }, LastBootUpTime,
    @{Name = 'Uptime'; Expression = { New-TimeSpan -Start $_.LastBootUpTime -End (Get-Date) } },
    @{Name = 'ReportType'; Expression = { 'OSInfo' } }

    #memory
    $cimOS | Select-Object -Property @{Name = 'Computername'; Expression = { $_.CSName } },
    @{Name="TotalPhysicalMemoryGB";Expression = {$_.TotalVisibleMemorySize/1mb -as [Int]}},
    @{Name = "FreeMemoryGB";Expression = { [math]::Round($_.FreePhysicalMemory/1mb,4)}},
    @{Name = "PctFreeMemory";Expression = { "{0:p2}" -f ($_.FreePhysicalMemory/$_.TotalVisibleMemorySize)}},
    @{Name = 'ReportType'; Expression = { 'MemInfo' } }

    #disk information
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" |
    Select-Object -Property @{Name = 'Computername'; Expression = { $_.SystemName } },
    @{Name = 'SizeGB'; Expression = { $_.Size / 1gb -as [int] } },
    @{Name = 'FreeGB'; Expression = { $_.FreeSpace / 1gb -as [int] } },
    @{Name = 'PctFree'; Expression = { '{0:p2}' -f ($_.FreeSpace / $_.Size) } },
    Compressed, QuotasDisabled,
    @{Name = 'ReportType'; Expression = { 'DiskInfo' } }

    #top processes
    Get-Process -IncludeUserName | Sort-Object -Property WorkingSet -Descending |
    Select-Object -First $using:ProcessCount -Property ID, ProcessName, UserName,
    @{Name = 'WorkingSet(MB)'; Expression = { [math]::Round($_.WorkingSet / 1MB, 2) } },
    Handles, StartTime,
    @{Name = 'Runtime'; Expression = { "{0:dd\.hh\:mm\:ss}" -f (New-TimeSpan -Start $_.StartTime -End (Get-Date)) } },
    @{Name = 'Computername'; Expression = { $env:ComputerName } },
    @{Name = 'ReportType'; Expression = { 'ProcessInfo' } }

    #critical service status
    #ignore errors for services that don't exist
    Get-Service -Name $using:svcList -ErrorAction SilentlyContinue |
    Select-Object -Property @{Name = "Service";Expression={"{0} ({1})" -f $_.DisplayName,$_.Name }},
    Status, StartType,
    @{Name = 'Computername'; Expression = { $env:ComputerName } },
    @{Name = 'ReportType'; Expression = { 'SvcInfo' } }

    #event log data
    $Since = (Get-Date).AddHours(-48).Date
    try {
        $logData = Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Level     = 2, 3
            StartTime = $Since
        } -ErrorAction Stop

        #write a custom object to the pipeline
        [PSCustomObject]@{
            Computername = $env:ComputerName
            LogName      = 'System'
            LogData      = $LogData
            Since        = $Since
            ReportType   = 'LogInfo'
        }
    } #try
    catch {
        Write-Warning "No recent errors or warnings in the System event log on $($env:ComputerName)."
    }
} #close script block

#parameters to splat to Invoke-Command
$icmParams = @{
    ErrorAction  = 'Stop'
    Computername = ''
    ScriptBlock  = $sb
    AsJob        = $true
    JobName      = ''
}
if ($Credential) {
    Write-Verbose "[$((Get-Date).TimeOfDay)] Adding support for an alternate credential"
    $icmParams.Add('Credential', $Credential)
}
#endregion

#region process each computer separately
foreach ($cn in $Computername) {
    $icmParams.Computername = $cn.ToUpper()
    $icmParams.JobName = "RemoteReportData-$cn"
    Write-Verbose "[$((Get-Date).TimeOfDay)] Invoking reporting scriptblock remotely on $($cn.ToUpper())"
    try {
        Invoke-Command @icmParams | ForEach-Object { $jobs.Add($_) }
    }
    catch {
        Write-Warning "Failed to run Invoke-Command on $($cn.ToUpper()). $($_.Exception.Message)"
    }
} #foreach computer
#endregion

#region waiting

#wait for jobs
Write-Verbose "[$((Get-Date).TimeOfDay)] Waiting for $($jobs.count) jobs to complete"
[void]($jobs | Wait-Job)

#endregion

#region create HTML report

#Process jobs in the order I want them processed
Write-Verbose "[$((Get-Date).TimeOfDay)] Processing job data"

$global:d = $data = $jobs | Receive-Job -Keep | Sort-Object -Property Computername

Write-Verbose "[$((Get-Date).TimeOfDay)] Building report from $($data.count) sources"
$data | Group-Object -Property Computername | ForEach-Object -Begin {
    #default parameters for Select-Object
    $selectParam = @{
        Property        = '*'
        ExcludeProperty = 'RunspaceID', '*Computername', 'ReportType'
    }

    Write-Verbose "[$((Get-Date).TimeOfDay)] Importing CSS from $(Resolve-Path $CSSPath)"
    $style = @"
<style>
$(Get-Content -Path $CSSPath -Raw)
</style>
"@

} -Process {
    $item = $_
    Write-Verbose "[$((Get-Date).TimeOfDay)] Creating report for $($item.Name)"
    $head = @"
$style
<Title>$ReportTitle - $($item.Name)</Title>
"@
    $fragments = @()
    $fragments += "<H1>$ReportTitle</H1>"
    $fileName = '{0:yyyy-MM-dd_hhmm}_{1}_SysReport.html' -f $rptDate, $item.Name
    $ReportFile = Join-Path $ReportPath -ChildPath $fileName
    #Computer name is an H2 heading
    $fragments += "<H2>$($item.Name) - $rptDate</H2>"

    'OSInfo','MemInfo','DiskInfo','ProcessInfo','SvcInfo', 'LogInfo' | ForEach-Object {
        $rType = $_
        $grpData = $item.group | Where-Object { $_.ReportType -eq $rType }
        switch ($rType) {
            'OSInfo' {
                $heading = 'Operating System Information'
                $as = 'List'
                [xml]$html = $grpData | Select-Object @selectParam |
                ConvertTo-Html -As $as -Fragment

                for ($i = 0; $i -le $html.table.tr.count - 1; $i++) {
                    $class = $html.CreateAttribute('class')
                    $class.Value = 'listProperty'
                    [void]($html.table.tr[$i].ChildNodes[0].Attributes.Append($class))
                }
                $content = $html.InnerXml
            }
            'MemInfo' {
                $heading = 'Memory Information'
                $as = 'List'
                [xml]$html = $grpData | Select-Object @selectParam |
                ConvertTo-Html -As $as -Fragment

                for ($i = 0; $i -le $html.table.tr.count - 1; $i++) {
                    $class = $html.CreateAttribute('class')
                    $class.Value = 'listProperty'
                    [void]($html.table.tr[$i].ChildNodes[0].Attributes.Append($class))
                }

                #check the value of the percent free column and assign a class to the row
                if (($html.table.tr[2].td[1].replace("%","") -as [double]) -le 25) {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'alert'
                    [void]($html.table.tr[2].ChildNodes[1].Attributes.Append($class))
                }
                elseif (($html.table.tr[2].td[1].replace("%","") -as [double]) -le 50) {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'warning'
                    [void]($html.table.tr[2].ChildNodes[1].Attributes.Append($class))
                }
                $content = $html.InnerXml
            }
            'DiskInfo' {
                $heading = 'Drive C: Information'
                $as = 'List'
                [xml]$html = $grpData | Select-Object @selectParam | ConvertTo-Html -As $as -Fragment

                #check the value of the percent free column and assign a class to the row
                if (($html.table.tr[2].td[1].replace("%","") -as [double]) -le 10) {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'alert'
                    [void]($html.table.tr[2].ChildNodes[1].Attributes.Append($class))
                }
                elseif (($html.table.tr[2].td[1].replace("%","") -as [double]) -le 20) {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'warning'
                    [void]($html.table.tr[2].ChildNodes[1].Attributes.Append($class))
                }

                if ($html.table.tr[3].td[1] -eq 'False') {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'warning'
                    [void]($html.table.tr[3].ChildNodes[1].Attributes.Append($class))
                }
                else {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'ok'
                    [void]($html.table.tr[3].ChildNodes[1].Attributes.Append($class))
                }

                if ($html.table.tr[4].td[1] -eq 'false') {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'warning'
                    [void]($html.table.tr[4].ChildNodes[1].Attributes.Append($class))
                }
                else {
                    $class = $html.CreateAttribute('class')
                    $class.value = 'ok'
                    [void]($html.table.tr[4].ChildNodes[1].Attributes.Append($class))
                }

                for ($i = 0; $i -le $html.table.tr.count - 1; $i++) {
                    $class = $html.CreateAttribute('class')
                    $class.Value = 'listProperty'
                    [void]($html.table.tr[$i].ChildNodes[0].Attributes.Append($class))
                }

                $content = $html.InnerXml
            }
            'ProcessInfo' {
                $heading = "Top $ProcessCount Processes"
                $as = 'Table'
                $content = $grpData | Sort-Object 'WorkingSet(MB)' -Descending |
                Select-Object @selectParam | ConvertTo-Html -As $as -Fragment
            }
            'SvcInfo' {
                $heading = 'Critical Service Status'
                $as = 'table'
                [xml]$html = $grpData | Sort-Object -Property Service |
                Select-Object @selectParam | ConvertTo-Html -As $as -Fragment
                for ($i = 1; $i -le $html.table.tr.count - 1; $i++) {
                    #check the value of the percent free memory column and assign a class to the row
                    if ($html.table.tr[$i].td[1] -eq 'Stopped') {
                        $class = $html.CreateAttribute('class')
                        $class.value = 'alert'
                    }
                    else {
                        $class = $html.CreateAttribute('class')
                        $class.value = 'ok'
                    }
                  [void]($html.table.tr[$i].Attributes.Append($class))
                }
                $content = $html.InnerXml
            }
            'LogInfo' {
                $heading = 'System Log Information'
                $as = 'Table'
                [xml]$html = $grpData.LogData |
                Select-Object -ExcludeProperty RunspaceID, *Computername, ReportType -Property TimeCreated,
                @{Name = 'Source'; Expression = { $_.ProviderName } },
                @{Name = 'Type'; Expression = { $_.LevelDisplayName } }, ID, Message |
                ConvertTo-Html -As $as -Fragment

                for ($i = 1; $i -le $html.table.tr.count - 1; $i++) {
                    #check the value of the percent free memory column and assign a class to the row
                    if ($html.table.tr[$i].td[2] -eq 'Error') {
                        $class = $html.CreateAttribute('class')
                        $class.value = 'alertBg'
                    }
                    else {
                        $class = $html.CreateAttribute('class')
                        $class.value = 'warningBg'
                    }
                    [void]($html.table.tr[$i].Attributes.Append($class))
                }

                $content = $html.InnerXml
            }
        } #switch
        Write-Verbose "[$((Get-Date).TimeOfDay)] ...$heading"
        $fragments += "<H3>$heading</H3>"
        $fragments += $content
    } #foreach report type

    #add metadata to the footer to document where this report originated
    $fragments += @"
    <p class='footer'>
    Report run: $rptDate by $($env:Userdomain)\$($env:username) from $($env:ComputerName)<br>
    Report source: $($MyInvocation.MyCommand.Source) v$ver
    </p>
"@
    ConvertTo-Html -Body $fragments -head $head | Out-File -FilePath $ReportFile
    if ($Passthru) {
        Get-Item -Path $ReportFile
    }
}

#endregion

#region cleanup
#remove jobs
Write-Verbose "[$((Get-Date).TimeOfDay)] Removing $($jobs.count) jobs"
$jobs | Remove-Job

Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($MyInvocation.MyCommand.Source)"
Write-Host "See $ReportFile for details." -ForegroundColor Green
#endregion
