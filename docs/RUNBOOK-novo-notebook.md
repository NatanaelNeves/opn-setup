# Runbook — Preparação de notebook

Tempo: 40–90 min (~15 min de interação). Requisitos: rede, credencial M365 do
colaborador (Pro/OOBE), senha padrão da TI, acesso ao cofre.

## 1. Base
Novo: Windows de fábrica. Usado: Configurações > Sistema > Recuperação >
Redefinir este PC > Remover tudo.

## 2. OOBE
- **Pro:** "Configurar para trabalho ou escola" → conta M365 do colaborador.
- **Home:** tela de rede → `Shift+F10` → `start ms-cxh:localonly` → conta local
  `setup-temp`. Registre `setup-temp` em organization.temporarySetupUser (settings.json)
  para que o setup agende a remoção dela.

## 3. Setup
PowerShell **como Administrador**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1 | iex
```
Informe nome `OPN-UF-NNNN` e a senha padrão da TI quando solicitado.
Revise `C:\OPN\Logs\setup-report.json`.

## 4. Pós-setup
- Reiniciar (aplica nome, políticas e remove conta temporária).
- **Home:** criar a conta do colaborador (Configurações > Contas > Outros usuários,
  tipo Usuário padrão); no 1º login ele entra com a conta M365 no OneDrive/Office/Teams.
- Colar etiqueta física com o nome.

## 5. Entrega
Preencher CHECKLIST-entrega.md, registrar no inventário, colher assinatura do termo.

## Problemas comuns
- *winget ausente:* abrir a Microsoft Store, atualizar "Instalador de Aplicativo"
  (ou https://aka.ms/getwinget), reexecutar.
- *OneDrive não logou (Home):* usuário abre o OneDrive e entra com a conta M365.
- *Wallpaper não travou:* reiniciar; se persistir, registrar a build no CHANGELOG.
- *BitLocker pulado:* sem TPM pronto; verificar TPM na BIOS/UEFI.
