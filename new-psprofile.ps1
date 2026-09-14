#create PowerShell Profile scripts

#PowerShell 5.1 profile
$path = "C:\Users\$($env:UserName)\Documents\WindowsPowerShell\profile.ps1"
New-Item $path -Force | Out-Null
$content = @'
<# Establish Proxy Credentials #>
$global:proxyAddress = 'http://172.31.245.222:8888'
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

#re-establish default repository
Try {
    $p = Get-PSRepository PSGallery -ErrorAction Stop
}
catch {
    Try {
        Write-Host "Re-registering default repository" -foreground Green
        Register-PSRepository -Default -ErrorAction Stop
    }
    Catch {
        Write-Host "Re-registering default repository with proxy credentials" -foreground yellow
        Register-PSRepository -Default -Proxy $ProxyAddress -ProxyCredential $proxyCredential
    }
}
Set-Location C:\
Clear-Host
'@

$content | Out-File $path

#PowerShell 7 profile
$path = "C:\Users\$($env:username)\Documents\PowerShell\profile.ps1"
New-Item $path -Force | Out-Null
$content | Out-File $path -Force