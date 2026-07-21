# Runbook — Operação contínua

## Adicionar/atualizar um app para toda a frota
1. Edite `applications.required` (ou `optional`) no settings.json.
2. Aumente `version` (semver: 1.0.0 → 1.0.1).
3. Commit/push. Em até 24h a manutenção diária instala/atualiza em todas.

## App para uma máquina específica
`applications.perMachine`: `"OPN-CE-PGG1": ["OBSProject.OBSStudio"]` → suba version → commit.

## Instalação pontual (via AnyDesk)
UAC → `opn-admin` + senha; ou `winget install --id <ID> --silent` num PowerShell elevado.

## Rotação da senha do admin (a cada 6 meses / saída de técnico)
Via Action1 (ou script em lote), empurrar para a frota:
`net user opn-admin "NOVA-SENHA-FORTE"`  → atualizar o cofre. NUNCA no repositório.

## Push de emergência (não esperar 24h)
Action1: executar `C:\OPN\Repository\maintenance\OPN-Maintenance.ps1` nas máquinas alvo.

## Máquina "fora do padrão"
A manutenção diária reaplica políticas e branding. Forçar agora:
`Start-ScheduledTask -TaskName OPN-Maintenance` (ou reexecutar o bootstrap).

## Notebook roubado/perdido
1. Bloquear a conta M365 do colaborador (Entra admin center).
2. Dados protegidos por BitLocker/Device Encryption; arquivos estão no OneDrive.
3. Registrar no inventário como "baixa".

## Colaborador desligado (offboarding)
Bloquear conta M365 no dia; na devolução, Redefinir este PC > Remover tudo e reimplantar.

## Máquina passa para outro colaborador (sem reinstalar)
Logue como `opn-admin`, va em `C:\OPN\Repository` e rode `.\New-OPNUser.ps1` de novo
com o nome da nova pessoa. A conta anterior (e qualquer outra que tenha sobrado) e
removida no proximo boot, com backup local previo em `C:\OPN\ProfileBackups\`.
