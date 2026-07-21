# OPN.System.psm1 - Conta admin (senha unica), nome, energia, idioma, Explorer, conta temporaria.

function Set-OPNLocalAdmin {
    param(
        [Parameter(Mandatory)][string]$UserName,
        [securestring]$Password,
        [switch]$NonInteractive
    )
    $u = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if (-not $u) {
        if (-not $Password) {
            if ($NonInteractive) { throw "conta $UserName inexistente em modo silencioso" }
            # Politica da ONG: UMA senha padrao da TI para toda a frota.
            # Regras: longa, exclusiva deste papel, rotacionada a cada 6 meses e
            # imediatamente na saida de qualquer tecnico (rotacao em massa via Action1).
            $Password = Read-Host "Senha padrao da TI para '$UserName'" -AsSecureString
        }
        New-LocalUser -Name $UserName -Password $Password -PasswordNeverExpires `
            -Description 'Administrador local - TI O Pequeno Nazareno' | Out-Null
        Write-OPNLog "  conta $UserName criada"
    } elseif ($Password) {
        # Permite alinhar a senha da frota rodando o setup com -AdminPassword.
        Set-LocalUser -Name $UserName -Password $Password
        Write-OPNLog "  senha de $UserName atualizada"
    }
    $isMember = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*\$UserName" }
    if (-not $isMember) { Add-LocalGroupMember -Group 'Administrators' -Member $UserName }
}

function Set-OPNComputerName {
    param([string]$Name, [Parameter(Mandatory)][string]$Pattern,
          [bool]$Ask = $true, [switch]$NonInteractive)
    if ($NonInteractive) { return }
    if (-not $Name -and $Ask) { $Name = Read-Host 'Nome da maquina (ex.: OPN-CE-0042)' }
    if (-not $Name) { Write-OPNLog '  nome nao informado - etapa pulada' 'WARN'; return }
    if ($Name -notmatch $Pattern) { throw "nome '$Name' fora do padrao OPN-UF-NNNN" }
    if ($env:COMPUTERNAME -ieq $Name) { Write-OPNLog '  nome ja correto'; return }
    Rename-Computer -NewName $Name -Force
    Write-OPNLog '  nome sera aplicado no proximo reinicio'
}

function Set-OPNPower {
    param($Power)
    $scheme = if ($Power.powerPlan -eq 'HighPerformance') { 'SCHEME_MIN' } else { 'SCHEME_BALANCED' }
    powercfg /setactive $scheme                                        | Out-Null
    powercfg /change standby-timeout-ac $Power.sleepACMinutes          | Out-Null
    powercfg /change standby-timeout-dc $Power.sleepBatteryMinutes     | Out-Null
    powercfg /change monitor-timeout-ac $Power.monitorACMinutes        | Out-Null
    powercfg /change monitor-timeout-dc $Power.monitorBatteryMinutes   | Out-Null
    $lid = switch ($Power.lidCloseAction) { 'Nothing' {0} 'Hibernate' {2} 'Shutdown' {3} default {1} }
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $lid | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $lid | Out-Null
    powercfg /setactive SCHEME_CURRENT                                  | Out-Null
    if ($Power.hibernate) { powercfg /h on 2>$null } else { powercfg /h off 2>$null }
}

function Set-OPNLanguage {
    param($Windows)
    if (-not $Windows.configureLanguage) { Write-OPNLog '  configureLanguage = false'; return }
    $lang = $Windows.language
    Set-WinUserLanguageList $lang -Force
    Set-WinSystemLocale $lang
    if ($lang -eq 'pt-BR') { Set-WinHomeLocation -GeoId 32 }
    Set-TimeZone $Windows.timeZone
    try { Set-Culture $lang } catch { Write-OPNLog '  Set-Culture indisponivel nesta sessao' 'WARN' }
}

function Set-OPNExplorerDefaults {
    param($Explorer, [string]$AdminAccount)
    $adv = @{}
    $adv['HideFileExt']        = if ($Explorer.showFileExtensions) { 0 } else { 1 }
    $adv['Hidden']             = if ($Explorer.showHiddenFiles)    { 1 } else { 2 }
    $adv['LaunchTo']           = if ($Explorer.openThisPC)         { 1 } else { 2 }
    if ($Explorer.disableWidgets) { $adv['TaskbarDa'] = 0 }
    if ($Explorer.disableChat)    { $adv['TaskbarMn'] = 0 }
    $adv['ShowTaskViewButton'] = 0
    Invoke-OPNPerUserHive -ExcludeUsers @() -Action {
        param($Base, $ProfileName)
        $key = "$Base\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        foreach ($n in $adv.Keys) { Set-OPNReg $key $n $adv[$n] }
    }.GetNewClosure()
    if ($Explorer.disableCopilot) {
        # Politica por maquina (Pro) + por usuario (funciona no Home).
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
        Invoke-OPNPerUserHive -ExcludeUsers @() -Action {
            param($Base, $ProfileName)
            Set-OPNReg "$Base\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
        }.GetNewClosure()
    }
}

function Remove-OPNTemporarySetupUser {
    # Agenda a remocao da conta temporaria de setup no proximo boot (SYSTEM),
    # pois nao da para apagar a conta em uso na sessao atual.
    param([string]$TempUser, [string]$AdminAccount)
    if ([string]::IsNullOrWhiteSpace($TempUser)) { Write-OPNLog '  nenhuma conta temporaria informada'; return }
    if ($TempUser -ieq $AdminAccount) { throw 'conta temporaria nao pode ser a conta admin da TI' }
    if (-not (Get-LocalUser $TempUser -ErrorAction SilentlyContinue)) {
        Write-OPNLog "  conta '$TempUser' nao existe"; return
    }
    $cmd = "net user `"$TempUser`" /delete & rmdir /s /q `"C:\Users\$TempUser`" & schtasks /delete /tn OPN-RemoveTempUser /f"
    $action  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $cmd"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName 'OPN-RemoveTempUser' -Action $action -Trigger $trigger `
        -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-OPNLog "  conta '$TempUser' sera removida no proximo reinicio"
}

Export-ModuleMember -Function Set-OPNLocalAdmin, Set-OPNComputerName, Set-OPNPower,
    Set-OPNLanguage, Set-OPNExplorerDefaults, Remove-OPNTemporarySetupUser
