# OPN.Security.psm1 - Usuarios padrao, UAC, Defender, Firewall e BitLocker.

function Set-OPNStandardUsers {
    param([Parameter(Mandatory)]$Security, [Parameter(Mandatory)][string]$AdminAccount)
    if (-not $Security.removeUsersFromAdministrators) { Write-OPNLog '  removeUsersFromAdministrators = false'; return }
    # Quem estiver rodando o setup agora fica admin ate o proximo boot (quando perfis
    # sobrando, incluindo o dele, sao removidos por Remove-OPNStaleProfiles).
    $keep = @($AdminAccount, $env:USERNAME, 'Administrator', 'Administrador')
    $adminGroup = Get-OPNAdminGroup
    $members = Get-LocalGroupMember -Group $adminGroup -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        $short = $m.Name.Split('\')[-1]
        if ($short -in $keep) { continue }
        if ($m.ObjectClass -eq 'Group') { continue }
        if ($m.PrincipalSource -eq 'AzureAD' -and $short -match '^(admin|ti)') { continue }
        try {
            Remove-LocalGroupMember -Group $adminGroup -Member $m.Name -ErrorAction Stop
            Write-OPNLog "  rebaixado a usuario padrao: $($m.Name)"
        } catch { Write-OPNLog "  nao rebaixou $($m.Name): $($_.Exception.Message)" 'WARN' }
    }
}

function Set-OPNSecurityBaseline {
    param([Parameter(Mandatory)]$Security)
    if ($Security.enableUAC) {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Set-OPNReg $k 'EnableLUA' 1
        Set-OPNReg $k 'ConsentPromptBehaviorAdmin' 5
        Set-OPNReg $k 'PromptOnSecureDesktop' 1
    }
    if ($Security.enableFirewall) {
        Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
        Write-OPNLog '  firewall ativo nos 3 perfis'
    }
    if ($Security.enableDefender) {
        try {
            Set-MpPreference -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples `
                -PUAProtection Enabled -ErrorAction Stop
            Write-OPNLog '  Defender: nuvem + PUA ativados'
        } catch { Write-OPNLog "  Defender: $($_.Exception.Message)" 'WARN' }
        Write-OPNLog '  lembrete: manter Tamper Protection LIGADA (nao configuravel por script)'
    }
    if ($Security.enableControlledFolderAccess) {
        try { Set-MpPreference -EnableControlledFolderAccess Enabled } catch {}
    }
    if ($Security.enableMemoryIntegrity) {
        Set-OPNReg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 1
        Write-OPNLog '  Memory Integrity habilitada (efetiva apos reinicio; pode conflitar com drivers antigos)' 'WARN'
    }
    if ($Security.enableExploitProtection) {
        Write-OPNLog '  Exploit Protection: mantidos os padroes do sistema (recomendado)'
    }
}

function Enable-OPNDiskEncryption {
    param([Parameter(Mandatory)]$BitLocker, [Parameter(Mandatory)][bool]$IsPro)
    if (-not $BitLocker.enabled) { Write-OPNLog '  bitlocker.enabled = false'; return }
    $sys = $env:SystemDrive
    if (-not $IsPro) {
        if ($BitLocker.skipOnWindowsHome) {
            Write-OPNLog '  HOME: BitLocker gerenciado indisponivel.'
            Write-OPNLog '  Se suportado: Configuracoes > Privacidade e seguranca > Criptografia do dispositivo.' 'WARN'
            return
        }
    }
    $v = Get-BitLockerVolume -MountPoint $sys -ErrorAction Stop
    if ($v.ProtectionStatus -eq 'On') { Write-OPNLog '  BitLocker ja ativo'; return }
    $tpm = Get-Tpm -ErrorAction SilentlyContinue
    if (-not $tpm -or -not $tpm.TpmReady) { Write-OPNLog '  TPM indisponivel - BitLocker pulado' 'WARN'; return }
    Enable-BitLocker -MountPoint $sys -EncryptionMethod XtsAes128 `
        -RecoveryPasswordProtector -SkipHardwareTest | Out-Null
    $kp = (Get-BitLockerVolume $sys).KeyProtector |
          Where-Object KeyProtectorType -eq 'RecoveryPassword' | Select-Object -First 1
    if ($BitLocker.backupRecoveryKey) {
        try {
            BackupToAAD-BitLockerKeyProtector -MountPoint $sys -KeyProtectorId $kp.KeyProtectorId | Out-Null
            Write-OPNLog '  BitLocker ativado; chave de recuperacao no Entra ID'
        } catch {
            $out = 'C:\OPN\Logs\bitlocker-recovery.txt'
            "Maquina: $env:COMPUTERNAME`nID: $($kp.KeyProtectorId)`nSenha: $($kp.RecoveryPassword)" | Set-Content $out
            Write-OPNLog "  ATENCAO: chave NAO foi ao Entra. Copie $out para o cofre e APAGUE o arquivo." 'WARN'
        }
    }
}

Export-ModuleMember -Function Set-OPNStandardUsers, Set-OPNSecurityBaseline, Enable-OPNDiskEncryption
