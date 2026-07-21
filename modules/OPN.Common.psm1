# OPN.Common.psm1 - Nucleo: log, registro, edicao, passos, hives por usuario, relatorio.
$script:LogFile = $null
$script:StepResults = [ordered]@{}

function Start-OPNLog {
    param([string]$Path = 'C:\OPN\Logs')
    New-Item $Path -ItemType Directory -Force | Out-Null
    $script:LogFile = Join-Path $Path ("setup-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
    Write-OPNLog "==== OPN Setup v2 iniciado em $env:COMPUTERNAME ===="
}

function Write-OPNLog {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO')
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1,-5}] {2}" -f (Get-Date), $Level, $Message
    if ($script:LogFile) { Add-Content $script:LogFile $line -Encoding UTF8 }
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}

function Get-OPNEdition {
    $ed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    [pscustomobject]@{ EditionID = $ed; IsPro = ($ed -match 'Professional|Enterprise|Education|Business') }
}

function Get-OPNAdminGroup {
    # Nome do grupo local "Administrators" muda por idioma do Windows (ex.: "Administradores"
    # em pt-BR). O SID S-1-5-32-544 e fixo em qualquer idioma - resolvemos o nome por ele.
    (Get-LocalGroup -SID 'S-1-5-32-544').Name
}

function Set-OPNReg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord','String','ExpandString','QWord','Binary')][string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

function Invoke-OPNStep {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    try {
        Write-OPNLog ">> $Name"
        & $Action
        $script:StepResults[$Name] = 'OK'
        Write-OPNLog "OK $Name"
    } catch {
        $script:StepResults[$Name] = "ERRO: $($_.Exception.Message)"
        Write-OPNLog "FALHA em '$Name': $($_.Exception.Message)" 'ERROR'
    }
}

function Invoke-OPNPerUserHive {
    # Executa $Action recebendo o caminho-base do hive de cada perfil de usuario:
    # o template (Default), todos os perfis locais existentes e o HKCU da sessao atual.
    # -ExcludeUsers: nomes de perfil que NAO devem receber (ex.: conta admin da TI).
    param(
        [Parameter(Mandatory)][scriptblock]$Action,   # param($HiveBasePath, $ProfileName)
        [string[]]$ExcludeUsers = @()
    )
    $targets = @(@{ Dat = 'C:\Users\Default\NTUSER.DAT'; Name = 'Default' })
    Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('Default','Public','All Users','Default User') + $ExcludeUsers } |
        ForEach-Object {
            $dat = Join-Path $_.FullName 'NTUSER.DAT'
            if (Test-Path $dat) { $targets += @{ Dat = $dat; Name = $_.Name } }
        }
    foreach ($t in $targets) {
        $key = "OPN_$($t.Name -replace '[^A-Za-z0-9]','_')"
        $loaded = $false
        try {
            reg load "HKU\$key" $t.Dat 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { continue }   # hive em uso (perfil logado): pulamos
            $loaded = $true
            & $Action "Registry::HKEY_USERS\$key" $t.Name
        } catch {
            Write-OPNLog "  perfil $($t.Name): $($_.Exception.Message)" 'WARN'
        } finally {
            if ($loaded) { [gc]::Collect(); Start-Sleep -Milliseconds 400
                           reg unload "HKU\$key" 2>$null | Out-Null }
        }
    }
    # Sessao atual (quem esta executando o setup):
    $me = $env:USERNAME
    if ($me -notin $ExcludeUsers) {
        try { & $Action 'Registry::HKEY_CURRENT_USER' $me }
        catch { Write-OPNLog "  perfil $me (sessao atual): $($_.Exception.Message)" 'WARN' }
    }
}

function Export-OPNReport {
    param([string]$Path = 'C:\OPN\Logs')
    $ed = Get-OPNEdition
    $os = Get-CimInstance Win32_OperatingSystem
    $report = [pscustomobject]@{
        Computer  = $env:COMPUTERNAME
        Edition   = $ed.EditionID
        OSVersion = $os.Version
        Date      = (Get-Date -Format 's')
        Steps     = $script:StepResults
    }
    $file = Join-Path $Path 'setup-report.json'
    $report | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding UTF8
    Write-OPNLog '================ RELATORIO ================'
    foreach ($k in $script:StepResults.Keys) {
        $lvl = if ($script:StepResults[$k] -like 'ERRO*') { 'WARN' } else { 'INFO' }
        Write-OPNLog ("{0,-48} {1}" -f $k, $script:StepResults[$k]) $lvl
    }
    Write-OPNLog "Relatorio salvo em $file"
    return $report
}

Export-ModuleMember -Function Start-OPNLog, Write-OPNLog, Get-OPNEdition, Get-OPNAdminGroup, Set-OPNReg,
    Invoke-OPNStep, Invoke-OPNPerUserHive, Export-OPNReport
