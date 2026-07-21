# OPN.Maintenance.psm1 - Repositorio local e tarefa agendada de manutencao.

function Install-OPNRepoLocal {
    param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$LocalPath)
    if ((Resolve-Path $SourceRoot).Path -ieq $LocalPath) { Write-OPNLog '  ja executando do repositorio local'; return }
    New-Item $LocalPath -ItemType Directory -Force | Out-Null
    Copy-Item "$SourceRoot\*" $LocalPath -Recurse -Force
    Write-OPNLog "  repositorio copiado para $LocalPath"
}

function Register-OPNMaintenanceTask {
    param([Parameter(Mandatory)]$Maintenance, [Parameter(Mandatory)][string]$LocalPath)
    if (-not $Maintenance.enabled) { Write-OPNLog '  maintenance.enabled = false'; return }
    $script  = Join-Path $LocalPath 'maintenance\OPN-Maintenance.ps1'
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
    $triggers = @(New-ScheduledTaskTrigger -Daily -At $Maintenance.dailyTime)
    if ($Maintenance.runAtStartup) { $triggers += New-ScheduledTaskTrigger -AtStartup }
    $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries `
        -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'OPN-Maintenance' -Action $action -Trigger $triggers `
        -Settings $set -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-OPNLog "  tarefa OPN-Maintenance registrada (diaria as $($Maintenance.dailyTime)$(if($Maintenance.runAtStartup){' + inicializacao'}))"
}

Export-ModuleMember -Function Install-OPNRepoLocal, Register-OPNMaintenanceTask
