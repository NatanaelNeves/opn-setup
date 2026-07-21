<#
.SYNOPSIS
  OPN Setup v2 - Padronizacao de computadores (Windows HOME e PRO).
.DESCRIPTION
  Le config\settings.json, detecta a edicao e executa todos os modulos.
  Idempotente: pode rodar varias vezes; reutilizado pela manutencao diaria.
.PARAMETER ComputerName    Nome no padrao OPN-UF-CODIGO.
.PARAMETER AdminPassword   Senha padrao da TI (SecureString). Se omitida, e solicitada.
.PARAMETER MaintenanceMode Execucao silenciosa (usada pela tarefa agendada).
.EXAMPLE
  .\OPN-Setup.ps1 -ComputerName OPN-CE-PGG1
  .\OPN-Setup.ps1 -MaintenanceMode
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$ComputerName,
    [securestring]$AdminPassword,
    [switch]$MaintenanceMode
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Get-ChildItem "$Root\modules\*.psm1" | ForEach-Object { Import-Module $_.FullName -Force }

$Cfg = Get-Content "$Root\config\settings.json" -Raw | ConvertFrom-Json
$O   = $Cfg.organization
Start-OPNLog -Path $Cfg.logging.path
$Ed  = Get-OPNEdition
Write-OPNLog "Versao pacote: $($Cfg.version) | Edicao: $($Ed.EditionID) | Modo: $(if($Ed.IsPro){'PRO'}else{'HOME'}) | Manutencao: $MaintenanceMode"

# Aviso de configuracao pendente (nao bloqueia).
if (-not $MaintenanceMode) {
    if ([string]::IsNullOrWhiteSpace($O.tenantId))          { Write-OPNLog 'AVISO: organization.tenantId vazio -> OneDrive KFM nao sera aplicado' 'WARN' }
    if ([string]::IsNullOrWhiteSpace($Cfg.repository.rawBase)) { Write-OPNLog 'AVISO: repository.rawBase vazio -> auto-atualizacao ficara inativa' 'WARN' }
    if ($O.generateRandomAdminPassword) { Write-OPNLog 'AVISO: generateRandomAdminPassword=true mas nao ha escrow (LAPS). Recomendado false p/ senha unica.' 'WARN' }
}

if ($Cfg.deployment.createLocalAdmin) {
    Invoke-OPNStep 'Conta admin local da TI' {
        Set-OPNLocalAdmin -UserName $O.adminAccount -Password $AdminPassword -NonInteractive:$MaintenanceMode
    }
}
if ($Cfg.deployment.renameComputer) {
    Invoke-OPNStep 'Nome do computador' {
        Set-OPNComputerName -Name $ComputerName -Pattern $O.computerPattern `
            -Ask ([bool]$Cfg.deployment.askComputerName) -NonInteractive:$MaintenanceMode
    }
}
Invoke-OPNStep 'Remocao de bloatware' {
    Remove-OPNBloatware -WingetIds $Cfg.applications.removeWinget -AppxNames $Cfg.applications.removeAppx
}
Invoke-OPNStep 'Aplicativos obrigatorios' {
    Install-OPNApps -List $Cfg.applications.required -Label 'obrigatorios'
}
Invoke-OPNStep 'Aplicativos opcionais' {
    Install-OPNApps -List $Cfg.applications.optional -Label 'opcionais'
}
Invoke-OPNStep 'Aplicativos especificos desta maquina' {
    $extra = Get-OPNPerMachineApps -PerMachine $Cfg.applications.perMachine
    if ($extra.Count) { Install-OPNApps -List $extra -Label "perMachine ($env:COMPUTERNAME)" }
    else { Write-OPNLog '  nenhuma excecao para esta maquina' }
}
if ($Cfg.drivers.detectManufacturer) {
    Invoke-OPNStep 'Utilitario de drivers do fabricante' {
        Install-OPNDriverTool -Drivers $Cfg.drivers
    }
}
Invoke-OPNStep 'OneDrive (login silencioso + KFM)' {
    Set-OPNOneDrive -OneDrive $Cfg.onedrive -TenantId $O.tenantId
}
Invoke-OPNStep 'Branding (wallpaper + lockscreen)' {
    Set-OPNBranding -RepoRoot $Root -Branding $Cfg.branding -Restrictions $Cfg.restrictions
}
Invoke-OPNStep 'Plano de energia' {
    Set-OPNPower -Power $Cfg.power
}
Invoke-OPNStep 'Idioma e regiao' {
    if ($MaintenanceMode) { Write-OPNLog '  pulado em manutencao'; return }
    Set-OPNLanguage -Windows $Cfg.windows
}
if ($Cfg.windows.configureExplorer) {
    Invoke-OPNStep 'Explorer padronizado' {
        Set-OPNExplorerDefaults -Explorer $Cfg.explorer -AdminAccount $O.adminAccount
    }
}
Invoke-OPNStep 'Politicas via registro (HOME e PRO)' {
    Set-OPNRegistryPolicies -Restrictions $Cfg.restrictions -Windows $Cfg.windows -AdminAccount $O.adminAccount
}
Invoke-OPNStep 'Baseline de seguranca (UAC/Defender/Firewall)' {
    Set-OPNSecurityBaseline -Security $Cfg.security
}
if ($Cfg.bitlocker.enabled) {
    Invoke-OPNStep 'Criptografia de disco' {
        Enable-OPNDiskEncryption -BitLocker $Cfg.bitlocker -IsPro $Ed.IsPro
    }
}
if ($Cfg.security.removeUsersFromAdministrators) {
    Invoke-OPNStep 'Usuarios rebaixados a padrao' {
        Set-OPNStandardUsers -Security $Cfg.security -AdminAccount $O.adminAccount `
            -TemporarySetupUser $O.temporarySetupUser
    }
}
Invoke-OPNStep 'Repositorio local' {
    Install-OPNRepoLocal -SourceRoot $Root -LocalPath $Cfg.repository.localRepository
}
if ($Cfg.deployment.enableMaintenance) {
    Invoke-OPNStep 'Tarefa de manutencao diaria' {
        Register-OPNMaintenanceTask -Maintenance $Cfg.maintenance -LocalPath $Cfg.repository.localRepository
    }
}
if ($Cfg.inventory.enabled) {
    Invoke-OPNStep 'Inventario local' {
        $null = Save-OPNInventory -Inventory $Cfg.inventory -LogPath $Cfg.logging.path
    }
}
# Conta temporaria de setup: agenda remocao para o proximo boot (nunca em manutencao).
if (-not $MaintenanceMode -and $O.removeTemporarySetupUser -and $O.temporarySetupUser) {
    Invoke-OPNStep 'Agendar remocao da conta temporaria' {
        Remove-OPNTemporarySetupUser -TempUser $O.temporarySetupUser -AdminAccount $O.adminAccount
    }
}

if ($Cfg.deployment.generateReport) { $null = Export-OPNReport -Path $Cfg.logging.path }
if ($Cfg.maintenance.generateHeartbeat) { Send-OPNHeartbeat -Inventory $Cfg.inventory -Url $Cfg.maintenance.heartbeatUrl }

if (-not $MaintenanceMode) {
    Write-OPNLog 'CONCLUIDO. Reinicie a maquina para aplicar nome, politicas e remover conta temporaria.'
    Write-OPNLog 'Checklist: docs\CHECKLIST-entrega.md'
    if ($Cfg.deployment.rebootAfterDeployment) {
        Write-OPNLog 'Reiniciando em 30s (rebootAfterDeployment=true)...'
        shutdown /r /t 30 /c 'OPN Setup concluido - reiniciando'
    }
}
