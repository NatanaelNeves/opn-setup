# OPN.OneDrive.psm1 - Login silencioso + Known Folder Move (le flags do settings.json).
# Politicas lidas pelo cliente OneDrive: valem tambem no Windows HOME.

function Set-OPNOneDrive {
    param([Parameter(Mandatory)]$OneDrive, [string]$TenantId)
    if (-not $OneDrive.enabled) { Write-OPNLog '  onedrive.enabled = false'; return }
    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
    if ($OneDrive.silentLogin) { Set-OPNReg $k 'SilentAccountConfig' 1 }
    if ($OneDrive.enableKnownFolderMove) {
        if ([string]::IsNullOrWhiteSpace($TenantId)) {
            Write-OPNLog '  tenantId vazio em organization.tenantId - KFM nao aplicado' 'WARN'
        } else {
            Set-OPNReg $k 'KFMSilentOptIn' $TenantId 'String'
            Set-OPNReg $k 'KFMSilentOptInWithNotification' 0
            if ($OneDrive.blockOptOut) { Set-OPNReg $k 'KFMBlockOptOut' 1 }
        }
    }
    if ($OneDrive.filesOnDemand)        { Set-OPNReg $k 'FilesOnDemandEnabled' 1 }
    if ($OneDrive.blockPersonalOneDrive){ Set-OPNReg $k 'DisablePersonalSync' 1 }
}

Export-ModuleMember -Function Set-OPNOneDrive
