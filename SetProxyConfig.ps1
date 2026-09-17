#requires -version 5.1
#dot source this script
$global:proxyAddress = 'http://172.31.245.222:8888'

New-Item -Path ENV: -Name HTTP_Proxy -Value $global:proxyAddress | Out-Null

if (-not $global:proxyUser -and (Test-Path c:\proxy.txt)) {
    $global:proxyInfo = ((Get-Content c:\proxy.txt).split(':', 3)).trim()
    $global:proxyUser = $global:proxyInfo[0]
    $global:proxyPassword = $global:proxyInfo[1]
}
try {
    #validate the variables first
    $v = Get-Variable proxyUser, proxyPassword -Scope Global -ErrorAction Stop
    #define globally-scoped proxy settings
    $global:psecpasswd = ConvertTo-SecureString $global:proxyPassword -AsPlainText -Force
    $global:proxyCredential = [System.Management.Automation.PSCredential]::New($global:proxyUser, $global:psecpasswd)
    $global:wp = [System.Net.WebProxy]::new($global:proxyAddress)
    $global:wp.BypassProxyOnLocal = $true
    $global:wp.Credentials = $global:proxyCredential
    $global:webclient = New-Object System.Net.Webclient
    $global:webclient.proxy = $global:wp
    [System.Net.WebRequest]::DefaultWebProxy = $global:wp
}
catch {
    Write-Warning 'missing proxy information'
}