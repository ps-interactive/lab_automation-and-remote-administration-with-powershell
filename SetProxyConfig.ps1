#dot source this script
$global:proxyAddress = 'http://172.31.245.222:8888'
New-Item -Path ENV: -Name HTTP_Proxy -value $global:proxyAddress | Out-Null

if (-Not $global:proxyUser -AND (Test-Path c:\proxy.txt)) {
    $global:proxyInfo = ((Get-Content c:\proxy.txt).split(":",3)).trim()
    $global:proxyUser = $global:proxyInfo[0]
    $global:proxyPassword = $global:proxyInfo[1]
}
Try {
    $v = Get-Variable proxyUser,proxyPassword -scope Global -errorAction Stop
    $global:psecpasswd = ConvertTo-SecureString $global:proxyPassword -AsPlainText -Force
    $global:proxyCredential = [System.Management.Automation.PSCredential]::New($global:proxyUser, $global:psecpasswd)
    $global:wp = [System.Net.WebProxy]::new($global:proxyAddress)
    $global:wp.Credentials = $global:proxyCredential
    $global:webclient = New-Object System.Net.Webclient
    $global:webclient.proxy = $global:wp
    [System.Net.WebRequest]::DefaultWebProxy = $global:wp

    }
Catch {
    Write-Warning "missing proxy information"
}