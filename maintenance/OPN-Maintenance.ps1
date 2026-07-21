<#
.SYNOPSIS
  OPN Maintenance - roda diariamente como SYSTEM (tarefa agendada).
.DESCRIPTION
  1. Auto-atualizacao: compara version (semver) local x remoto; atualiza se houver nova.
  2. Reaplica a padronizacao em modo silencioso (corrige desvios).
  3. Atualiza apps via winget (com resolucao do winget no contexto SYSTEM).
  4. Heartbeat + limpeza de logs conforme logging.keepDays.
#>
$ErrorActionPreference = 'Continue'
$Repo   = 'C:\OPN\Repository'
$Cfg    = Get-Content "$Repo\config\settings.json" -Raw | ConvertFrom-Json
$LogDir = $Cfg.logging.path
New-Item $LogDir -ItemType Directory -Force | Out-Null
Start-Transcript -Path (Join-Path $LogDir 'maintenance-last.log') -Force

try {
    $localVer = $Cfg.version

    # ---- 1. Auto-atualizacao (comparacao semver correta) ----
    $updated = $false
    if ($Cfg.updates.checkForUpdates -and $Cfg.repository.rawBase) {
        try {
            $remote = Invoke-RestMethod "$($Cfg.repository.rawBase)/config/settings.json" -TimeoutSec 30
            $isNewer = $false
            try { $isNewer = ([version]$remote.version -gt [version]$localVer) }
            catch { $isNewer = ([string]$remote.version -gt [string]$localVer) }  # fallback
            if ($isNewer) {
                Write-Output "Nova versao: $($remote.version) (local $localVer). Atualizando..."
                $zip = Join-Path $env:TEMP 'opn-upd.zip'; $tmp = Join-Path $env:TEMP 'opn-upd'
                Invoke-WebRequest $Cfg.repository.zipUrl -OutFile $zip -UseBasicParsing
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Expand-Archive $zip $tmp -Force
                $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
                Copy-Item "$($inner.FullName)\*" $Repo -Recurse -Force
                Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
                $Cfg = Get-Content "$Repo\config\settings.json" -Raw | ConvertFrom-Json
                $updated = $true
            } else { Write-Output "Versao $localVer ja e a mais recente." }
        } catch { Write-Output "Sem acesso ao repositorio: $($_.Exception.Message). Usando versao local." }
    }

    # ---- 2. Reaplicar padronizacao (drift correction) ----
    if ($Cfg.maintenance.reapplyPolicies) {
        & "$Repo\OPN-Setup.ps1" -MaintenanceMode
    }

    # ---- 3. Atualizar apps via winget ----
    if ($Cfg.maintenance.upgradeWingetPackages) {
        $wg = (Get-Command winget -ErrorAction SilentlyContinue).Source
        if (-not $wg) {
            $wg = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" `
                  -ErrorAction SilentlyContinue | Sort-Object FullName -Descending |
                  Select-Object -First 1 -ExpandProperty FullName
        }
        if ($wg) {
            Write-Output 'Atualizando apps via winget...'
            & $wg upgrade --all --silent --accept-package-agreements --accept-source-agreements `
                --disable-interactivity 2>&1 | Select-Object -Last 15
        } else { Write-Output 'winget indisponivel no contexto SYSTEM.' }
    }

    # ---- 4. Heartbeat ----
    if ($Cfg.maintenance.generateHeartbeat -and $Cfg.maintenance.heartbeatUrl) {
        Get-ChildItem "$Repo\modules\OPN.Common.psm1","$Repo\modules\OPN.Inventory.psm1" |
            ForEach-Object { Import-Module $_.FullName -Force }
        Send-OPNHeartbeat -Inventory $Cfg.inventory -Url $Cfg.maintenance.heartbeatUrl
    }

    # ---- 5. Limpeza de logs (logging.keepDays) ----
    $keep = [int]$Cfg.logging.keepDays
    Get-ChildItem $LogDir -Filter 'setup-*.log' -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -lt (Get-Date).AddDays(-$keep) |
        Remove-Item -Force -ErrorAction SilentlyContinue

    if ($updated) { Write-Output 'Atualizacao aplicada.' }
} finally {
    Stop-Transcript | Out-Null
}
