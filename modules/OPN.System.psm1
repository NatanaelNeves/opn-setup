# OPN.System.psm1 - Conta admin (senha unica), nome + conta padrao do usuario,
# energia, idioma, Explorer, limpeza de perfis antigos.

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
    $adminGroup = Get-OPNAdminGroup
    $isMember = Get-LocalGroupMember -Group $adminGroup -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*\$UserName" }
    if (-not $isMember) { Add-LocalGroupMember -Group $adminGroup -Member $UserName }
}

function Set-OPNComputerName {
    # Retorna o nome resolvido (ou $null se pulado) para tambem virar o nome da
    # conta padrao do usuario (New-OPNStandardUser) - um so nome perguntado, dois usos.
    param([string]$Name, [Parameter(Mandatory)][string]$Pattern,
          [bool]$Ask = $true, [switch]$NonInteractive)
    if ($NonInteractive) { return $null }
    if (-not $Name -and $Ask) { $Name = Read-Host 'Nome da maquina (ex.: OPN-CE-PGG1)' }
    if (-not $Name) { Write-OPNLog '  nome nao informado - etapa pulada' 'WARN'; return $null }
    if ($Name -notmatch $Pattern) { throw "nome '$Name' fora do padrao OPN-UF-CODIGO" }
    if ($env:COMPUTERNAME -ieq $Name) { Write-OPNLog '  nome ja correto'; return $Name }
    Rename-Computer -NewName $Name -Force
    Write-OPNLog '  nome sera aplicado no proximo reinicio'
    return $Name
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
    try { Set-WinUserLanguageList $lang -Force } catch { Write-OPNLog "  idioma: $($_.Exception.Message)" 'WARN' }
    try { Set-WinSystemLocale $lang } catch { Write-OPNLog "  localidade: $($_.Exception.Message)" 'WARN' }
    if ($lang -eq 'pt-BR') {
        try { Set-WinHomeLocation -GeoId 32 } catch { Write-OPNLog "  regiao: $($_.Exception.Message)" 'WARN' }
    }
    # Em algumas imagens de Windows reduzidas (ex.: notebooks de laboratorio/escola) o ID
    # do fuso pode estar ausente da base local; nao deve derrubar o resto da configuracao.
    try { Set-TimeZone $Windows.timeZone } catch { Write-OPNLog "  fuso horario: $($_.Exception.Message)" 'WARN' }
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

function New-OPNStandardUser {
    # Conta padrao de quem vai usar esta maquina. Sem Intune/Entra Join, o Windows
    # nao cria essa conta sozinho a partir da conta M365 - o setup cria na hora, com
    # o mesmo nome da maquina (nao e uma conta pessoal por colaborador, e a conta
    # padrao desta maquina - simples de padronizar em varias maquinas).
    param([Parameter(Mandatory)][string]$UserName)
    if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
        Write-OPNLog "  conta '$UserName' ja existe - mantida"
        return
    }
    $tempPwd = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 14 | ForEach-Object { [char]$_ })
    $sec = ConvertTo-SecureString $tempPwd -AsPlainText -Force
    New-LocalUser -Name $UserName -Password $sec -Description 'Usuario padrao OPN' -AccountNeverExpires | Out-Null
    try {
        $obj = [adsi]"WinNT://$env:COMPUTERNAME/$UserName,user"
        $obj.PasswordExpired = 1
        $obj.SetInfo()
    } catch { Write-OPNLog "  nao marcou troca de senha obrigatoria: $($_.Exception.Message)" 'WARN' }
    $out = 'C:\OPN\Logs\usuario-senha-inicial.txt'
    New-Item (Split-Path $out) -ItemType Directory -Force | Out-Null
    "Maquina: $env:COMPUTERNAME`nUsuario: $UserName`nSenha inicial: $tempPwd`n(trocada obrigatoriamente no 1o login)" |
        Set-Content $out
    Write-OPNLog "  conta '$UserName' criada (usuario padrao). Senha inicial em $out - repasse ao colaborador e apague o arquivo" 'WARN'
}

function Remove-OPNStaleProfiles {
    # Padronizacao: todo perfil local que NAO for a conta da TI nem a conta do
    # colaborador definida nesta execucao e tratado como sobra (conta temporaria de
    # setup, aluno/usuario antigo etc.) e agendado para remocao no proximo boot -
    # inclusive o perfil que estiver rodando este script agora, que so pode ser
    # apagado depois que a sessao dele terminar. Antes de apagar, copia
    # Desktop/Documentos/Imagens/Downloads para C:\OPN\ProfileBackups\<perfil>\,
    # pois sem organization.tenantId nao ha backup automatico via OneDrive.
    param([Parameter(Mandatory)][string]$AdminAccount, [string]$KeepUser)
    $keep = @($AdminAccount, $KeepUser, 'Administrator', 'Administrador') | Where-Object { $_ }
    $skip = @('Default', 'Public', 'All Users', 'Default User') + $keep
    $stale = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $skip -and $_.Name -notmatch '^defaultuser\d+$' }
    if (-not $stale) { Write-OPNLog '  nenhum perfil sobrando para remover'; return }

    $backupRoot = 'C:\OPN\ProfileBackups'
    $cmds = @()
    foreach ($p in $stale) {
        Write-OPNLog "  perfil marcado para remocao no proximo boot: $($p.Name)"
        foreach ($folder in 'Desktop', 'Documents', 'Imagens', 'Pictures', 'Downloads') {
            $src = Join-Path $p.FullName $folder
            if (Test-Path $src) {
                $cmds += "robocopy `"$src`" `"$backupRoot\$($p.Name)\$folder`" /E /R:1 /W:1 >nul"
            }
        }
        $cmds += "net user `"$($p.Name)`" /delete"
        $cmds += "rmdir /s /q `"$($p.FullName)`""
    }
    $cmds += 'schtasks /delete /tn OPN-RemoveStaleProfiles /f'
    $action  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $($cmds -join ' & ')"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName 'OPN-RemoveStaleProfiles' -Action $action -Trigger $trigger `
        -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-OPNLog "  $($stale.Count) perfil(is) serao removidos no proximo reinicio (backup local em $backupRoot)"
    Write-OPNLog "  ATENCAO: mova $backupRoot para o cofre/nuvem da TI e apague depois - fica so nesta maquina" 'WARN'
}

Export-ModuleMember -Function Set-OPNLocalAdmin, Set-OPNComputerName, Set-OPNPower,
    Set-OPNLanguage, Set-OPNExplorerDefaults, New-OPNStandardUser, Remove-OPNStaleProfiles
