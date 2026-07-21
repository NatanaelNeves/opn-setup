# OPN.Apps.psm1 - Bloatware, apps obrigatorios/opcionais/por maquina.

function Test-OPNWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget nao encontrado. Atualize o "Instalador de Aplicativo" na Microsoft Store (https://aka.ms/getwinget).'
    }
}

function Remove-OPNBloatware {
    param([string[]]$WingetIds, [string[]]$AppxNames)
    foreach ($id in @($WingetIds)) {
        if (-not $id) { continue }
        winget uninstall --id $id --exact --silent --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-OPNLog "  removido (winget): $id" }
    }
    foreach ($name in @($AppxNames)) {
        if (-not $name) { continue }
        Get-AppxPackage -AllUsers -Name $name -ErrorAction SilentlyContinue |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object DisplayName -eq $name |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        Write-OPNLog "  removido (appx): $name"
    }
}

function Install-OPNApps {
    param([string[]]$List, [string]$Label = 'apps')
    if (-not $List -or $List.Count -eq 0) { Write-OPNLog "  nenhum item em $Label"; return }
    Test-OPNWinget
    foreach ($id in $List) {
        winget list --id $id --exact --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-OPNLog "  ja instalado: $id"; continue }
        Write-OPNLog "  instalando: $id"
        winget install --id $id --exact --silent --scope machine `
            --accept-package-agreements --accept-source-agreements *> $null
        if ($LASTEXITCODE -ne 0) {
            winget install --id $id --exact --silent `
                --accept-package-agreements --accept-source-agreements *> $null
        }
        if ($LASTEXITCODE -ne 0) { Write-OPNLog "  falha ao instalar $id (codigo $LASTEXITCODE)" 'WARN' }
    }
}

function Get-OPNPerMachineApps {
    # Le applications.perMachine.{NOME-DA-MAQUINA} do settings.json.
    param($PerMachine)
    if (-not $PerMachine) { return @() }
    $prop = $PerMachine.PSObject.Properties[$env:COMPUTERNAME]
    if ($prop) { return @($prop.Value) }
    return @()
}

Export-ModuleMember -Function Remove-OPNBloatware, Install-OPNApps, Get-OPNPerMachineApps
