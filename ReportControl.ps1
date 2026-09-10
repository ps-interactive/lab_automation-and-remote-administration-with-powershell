#requires -version 5.1
#requires -module Microsoft.PowerShell.ThreadJob

#control script for system reporting

Param([string]$ReportPath = 'C:\reports')

$domain = 'Dom1', 'Srv1', 'Srv2'
#It is assumed this script will be run on a domain join computer
Try {
    $dn = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
}
Catch {
    #ignore errors
}
$domCred = Get-Credential -Message 'Enter DOMAIN credential' -UserName "$($env:USERDOMAIN)\Administrator"

$wg1 = 'Srv3'
$wg1Cred = Get-Credential -Message "Enter $wg1 admin-level credential" -UserName "$wg1\Administrator"

#resolve full path to reporting script
$scriptPath = Convert-Path $PSScriptRoot\SystemReport.ps1
#run each reporting script as a thread job so that they run at the same time
#need to use $using to reference variables from the parent scope
$dt = Get-Date
Microsoft.PowerShell.ThreadJob\Start-ThreadJob -ScriptBlock { &$using:scriptPath -computerName $using:domain -credential $using:domCred -reportPath $using:ReportPath -passthru -Verbose } -Name rptJob -StreamingHost $Host
Microsoft.PowerShell.ThreadJob\Start-ThreadJob -ScriptBlock { &$using:scriptPath -computerName $using:wg1 -credential $using:wg1Cred -reportPath $using:ReportPath -passthru -Verbose } -Name rptJob -StreamingHost $Host

Write-Host "Waiting for $((Get-Job -Name rptJob).count) jobs to complete."
$files = Get-Job -Name rptJob | Wait-Job | Receive-Job

Remove-Job -Name rptJob

#create master HTML file
$filename = '{0:yyyy-MM-dd_hhmm}_System_Reports.html' -f $dt
$out = Join-Path -Path $ReportPath -ChildPath $filename

#initialize a list for the body
$fragments = [System.Collections.Generic.List[string]]::new()
$fragments.Add("<H1>System Reports for $($dt.ToString('d'))</H1>")
$fragments.Add('<H2> Server Reports</H2>')

foreach ($file in $files) {
    #parse the server name from the file name
    $name = $file.name.split('_')[2]
    if ($name -in $domain -AND $dn) {
        #append domain FQDNwho
        $name+=".$dn"
    }
    $link = "<a href=$($file.name) target=_blank>$Name</a>"
    #use a placeholder otherwise the tags get escaped
    $html = [PSCustomObject]@{
        Server     = '_Placeholder_'
        Date       = $file.LastWriteTime
        ReportSize = '{0}KB' -f ($file.Length / 1kb -as [int])
    } | ConvertTo-Html -As Table -Fragment
    #insert the correct HTML code now
    $html = $html.Replace('_Placeholder_', $link)
    $fragments.Add($html)
}

#Import CSS as header
#append a table width to force a width in this report
$head = @"
<title>System Reports $($dt.toString('d'))</title>
<style>
$(Get-Content (Convert-Path $PSScriptRoot\Alternating.css) -raw)
table {
    width:45%;
}
</style>
"@
ConvertTo-Html -Body ($fragments | Out-String) -head $head | Out-File -FilePath $out
Get-Item $out