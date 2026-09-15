#create PowerShell Profile scripts

#content for PowerShell profile script in Windows PowerShell and PowerShell 7
$content = @'
<# Establish Proxy Credentials #>

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. c:\scripts\SetProxyConfig.ps1

#re-establish default repository
Try {
    $p = Get-PSRepository PSGallery -ErrorAction Stop
}
catch {
    Try {
        Write-Host "Re-registering default repository with proxy credentials" -foreground yellow
        Register-PSRepository -Default -Proxy $ProxyAddress -ProxyCredential $proxyCredential -errorAction Stop
    }
    Catch {
        Write-Warning "Failed to re-register the PSGallery repository. $($_.Exception.Message)"
    }
}
Set-Location C:\
Clear-Host
'@

#PowerShell 5.1 profile for all users current host
$path = "C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1"
New-Item $path -Force | Out-Null

$content | Out-File $path -Force
Get-Item $Path

#PowerShell 7 profile
$path = "C:\Program Files\PowerShell\7\Microsoft.PowerShell_profile.ps1"
New-Item $path -Force | Out-Null
$content | Out-File $path -Force
Get-Item $Path