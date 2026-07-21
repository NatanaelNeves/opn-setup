# Runbook — Preparação de notebook

Tempo: 40–90 min (~15 min de interação). Requisitos: rede, senha padrão da TI,
acesso ao cofre.

## 1. Base
Novo: Windows de fábrica. Usado: Configurações > Sistema > Recuperação >
Redefinir este PC > Remover tudo.

## 2. OOBE
- **Pro:** "Configurar para trabalho ou escola" → conta M365 do colaborador.
- **Home:** tela de rede → `Shift+F10` → `start ms-cxh:localonly` → qualquer conta
  local temporária (ex.: `setup-temp`) só para rodar o setup. Não precisa registrar
  nada — é removida automaticamente no próximo boot.
- **Máquina já usada antes** (laboratório/sala, com contas antigas de outras
  pessoas): pode logar direto numa dessas contas existentes e rodar o setup a
  partir dela — também será removida no próximo boot.

## 3. Setup
PowerShell **como Administrador**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1 | iex
```
Informe nome `OPN-UF-CÓDIGO` (ex.: `OPN-CE-PGG1`) e a senha padrão da TI quando
solicitado. Revise `C:\OPN\Logs\setup-report.json`.

O setup cria `opn-admin` (TI) e uma conta local **usuário padrão com o mesmo nome
da máquina** (ex.: `OPN-CE-PGG1`) — é essa conta que o colaborador vai usar.

## 4. Pós-setup
- Reiniciar (aplica nome, políticas e remove qualquer perfil que não seja
  `opn-admin` nem a conta da máquina — inclusive a conta temporária usada para
  rodar o setup e contas antigas de outras pessoas).
- Repassar a senha inicial da conta (`C:\OPN\Logs\usuario-senha-inicial.txt`,
  trocada obrigatoriamente no 1º login) e, no caso Pro, o colaborador entra com a
  conta M365 no OneDrive/Office/Teams. **Apagar esse arquivo depois de repassar a
  senha.**
- Se algum perfil antigo foi removido, mover `C:\OPN\ProfileBackups\` (arquivos que
  pertenciam a essas contas) para o cofre da TI e só então apagar da máquina.
- Colar etiqueta física com o nome.

## 5. Entrega
Preencher CHECKLIST-entrega.md, registrar no inventário, colher assinatura do termo.

## Problemas comuns
- *winget ausente:* abrir a Microsoft Store, atualizar "Instalador de Aplicativo"
  (ou https://aka.ms/getwinget), reexecutar.
- *OneDrive não logou (Home):* usuário abre o OneDrive e entra com a conta M365.
- *Wallpaper não travou:* reiniciar; se persistir, registrar a build no CHANGELOG.
- *BitLocker pulado:* sem TPM pronto; verificar TPM na BIOS/UEFI.
