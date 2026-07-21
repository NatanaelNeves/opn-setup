# OPN.Policies.psm1 - Restricoes via registro (HOME e PRO), politicas por usuario
# (regedit/painel de controle) poupando a conta da TI.

function Set-OPNRegistryPolicies {
    param([Parameter(Mandatory)]$Restrictions, [Parameter(Mandatory)]$Windows,
          [Parameter(Mandatory)][string]$AdminAccount)

    # ---- Politicas de maquina (valem para todos) ----
    if ($Restrictions.settingsPagesVisible) {
        Set-OPNReg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
            'SettingsPageVisibility' $Restrictions.settingsPagesVisible 'String'
    }
    if ($Restrictions.blockPersonalMicrosoftAccounts) {
        Set-OPNReg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 3
    }
    if ($Windows.configureSmartScreen) {
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Block' 'String'
    }
    if ($Windows.configureWindowsUpdate) {
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 0
    }
    if ($Windows.disableConsumerExperience) {
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
        Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
    }
    # Bloqueio de tela apos 15 min de inatividade (exige senha ao voltar).
    Set-OPNReg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'InactivityTimeoutSecs' 900
    # Store: somente apps ja provisionados.
    Set-OPNReg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'RequirePrivateStoreOnly' 1

    # ---- Politicas POR USUARIO (nao afetam a conta da TI) ----
    $blockReg  = [bool]$Restrictions.blockRegistryEditor
    $blockCpl  = [bool]$Restrictions.blockControlPanel
    $blockCmd  = [bool]$Restrictions.blockCMD
    $noSuggest = [bool]$Windows.disableSuggestions
    Invoke-OPNPerUserHive -ExcludeUsers @($AdminAccount) -Action {
        param($Base, $ProfileName)
        if ($blockReg) { Set-OPNReg "$Base\Software\Microsoft\Windows\CurrentVersion\Policies\System" 'DisableRegistryTools' 1 }
        if ($blockCpl) { Set-OPNReg "$Base\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" 'NoControlPanel' 1 }
        if ($blockCmd) { Set-OPNReg "$Base\Software\Policies\Microsoft\Windows\System" 'DisableCMD' 1 }
        if ($noSuggest) {
            $cdm = "$Base\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            foreach ($n in 'SubscribedContent-338388Enabled','SubscribedContent-338389Enabled',
                           'SubscribedContent-353694Enabled','SubscribedContent-353696Enabled',
                           'SystemPaneSuggestionsEnabled','SilentInstalledAppsEnabled') {
                Set-OPNReg $cdm $n 0
            }
        }
    }.GetNewClosure()
}

Export-ModuleMember -Function Set-OPNRegistryPolicies
