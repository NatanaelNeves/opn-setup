# OPN.Branding.psm1 - Wallpaper e lockscreen institucionais, travados.

function Set-OPNBranding {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)]$Branding, [Parameter(Mandatory)]$Restrictions)
    if (-not $Branding.enabled) { Write-OPNLog '  branding.enabled = false'; return }
    $dir = 'C:\OPN\Branding'
    New-Item $dir -ItemType Directory -Force | Out-Null
    $wall = Join-Path $dir 'wallpaper.png'
    $lock = Join-Path $dir 'lockscreen.png'
    foreach ($pair in @(@{s=$Branding.wallpaper;d=$wall}, @{s=$Branding.lockscreen;d=$lock})) {
        $src = Join-Path $RepoRoot $pair.s
        if (Test-Path $src) { Copy-Item $src $pair.d -Force }
        else { Write-OPNLog "  aviso: $src ausente" 'WARN' }
    }
    if (Test-Path $wall) {
        $csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
        Set-OPNReg $csp 'DesktopImagePath'   $wall 'String'
        Set-OPNReg $csp 'DesktopImageUrl'    $wall 'String'
        Set-OPNReg $csp 'DesktopImageStatus' 1
        if (Test-Path $lock) {
            Set-OPNReg $csp 'LockScreenImagePath'   $lock 'String'
            Set-OPNReg $csp 'LockScreenImageUrl'    $lock 'String'
            Set-OPNReg $csp 'LockScreenImageStatus' 1
        }
    }
    if ($Restrictions.blockWallpaperChange) {
        Set-OPNReg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop' 'NoChangingWallPaper' 1
    }
    Start-Process rundll32.exe 'user32.dll,UpdatePerUserSystemParameters' -WindowStyle Hidden -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Set-OPNBranding
