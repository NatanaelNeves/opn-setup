# OPN.Inventory.psm1 - Coleta inventario e envia heartbeat (Power Automate/SharePoint).

function Get-OPNInventory {
    param([Parameter(Mandatory)]$Inventory)
    $data = [ordered]@{
        computer  = $env:COMPUTERNAME
        user      = (Get-CimInstance Win32_ComputerSystem).UserName
        timestamp = (Get-Date -Format 's')
    }
    if ($Inventory.collectWindowsVersion) {
        $os = Get-CimInstance Win32_OperatingSystem
        $data.edition   = (Get-OPNEdition).EditionID
        $data.osVersion = $os.Version
        $data.osBuild   = $os.BuildNumber
    }
    if ($Inventory.collectHardware) {
        $cs  = Get-CimInstance Win32_ComputerSystem
        $bio = Get-CimInstance Win32_BIOS
        $dsk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $data.model      = "$($cs.Manufacturer) $($cs.Model)".Trim()
        $data.serial     = $bio.SerialNumber
        $data.ramGB      = [math]::Round($cs.TotalPhysicalMemory / 1GB, 0)
        $data.diskFreeGB = [math]::Round($dsk.FreeSpace / 1GB, 1)
    }
    if ($Inventory.collectBitLocker) {
        try { $data.bitlocker = "$((Get-BitLockerVolume $env:SystemDrive -ErrorAction Stop).ProtectionStatus)" }
        catch { $data.bitlocker = 'N/A' }
    }
    if ($Inventory.collectInstalledApps -or $Inventory.collectSoftware) {
        $apps = @()
        foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
            $apps += Get-ItemProperty $k -ErrorAction SilentlyContinue |
                     Where-Object DisplayName | Select-Object -ExpandProperty DisplayName
        }
        $data.installedApps = @($apps | Sort-Object -Unique)
        $data.appCount = $data.installedApps.Count
    }
    if (Test-Path 'C:\OPN\Repository\config\settings.json') {
        $data.opnVersion = (Get-Content 'C:\OPN\Repository\config\settings.json' -Raw | ConvertFrom-Json).version
    }
    [pscustomobject]$data
}

function Save-OPNInventory {
    param([Parameter(Mandatory)]$Inventory, [string]$LogPath = 'C:\OPN\Logs')
    if (-not $Inventory.enabled) { Write-OPNLog '  inventory.enabled = false'; return $null }
    $inv = Get-OPNInventory -Inventory $Inventory
    $inv | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $LogPath 'inventory.json') -Encoding UTF8
    Write-OPNLog "  inventario salvo em $LogPath\inventory.json"
    return $inv
}

function Send-OPNHeartbeat {
    param([Parameter(Mandatory)]$Inventory, [string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return }
    try {
        $inv  = Get-OPNInventory -Inventory $Inventory
        # Heartbeat enxuto (sem lista completa de apps, que pode ser grande):
        $body = $inv | Select-Object * -ExcludeProperty installedApps | ConvertTo-Json
        Invoke-RestMethod -Uri $Url -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 30 | Out-Null
        Write-OPNLog '  heartbeat enviado'
    } catch { Write-OPNLog "  heartbeat falhou: $($_.Exception.Message)" 'WARN' }
}

Export-ModuleMember -Function Get-OPNInventory, Save-OPNInventory, Send-OPNHeartbeat
