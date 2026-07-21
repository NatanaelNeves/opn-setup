# Runbook — Preparação de notebook

Tempo: 40–90 min (~15 min de interação). Requisitos: rede, senha padrão da TI,
acesso ao cofre. Em duas etapas: **Preparo** (não precisa saber quem vai receber a
máquina) e **Entrega** (quando já se sabe).

## Preparo

### 1. Base
Novo: Windows de fábrica. Usado: Configurações > Sistema > Recuperação >
Redefinir este PC > Remover tudo.

### 2. OOBE
- **Pro:** "Configurar para trabalho ou escola" → conta M365 do colaborador (essa
  conta já existe quando o setup roda; nada a fazer na entrega).
- **Home:** tela de rede → `Shift+F10` → `start ms-cxh:localonly` → qualquer conta
  local temporária (ex.: `setup-temp`). Não precisa registrar nada — é removida
  automaticamente na entrega.
- **Máquina já usada antes** (laboratório/sala, com contas antigas de outras
  pessoas): pode logar direto numa dessas contas existentes e rodar o preparo a
  partir dela — também será removida na entrega.

### 3. Setup
PowerShell **como Administrador**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1 | iex
```
Informe nome `OPN-UF-CÓDIGO` (ex.: `OPN-CE-PGG1`) e a senha padrão da TI quando
solicitado. Revise `C:\OPN\Logs\setup-report.json`. Reinicie ao final.

## Entrega
Quando já se sabe quem vai receber a máquina:

### 4. Criar a conta do colaborador
PowerShell **como Administrador**:
```powershell
cd C:\OPN\Repository
.\New-OPNUser.ps1
```
Informe nome completo, usuário (ex.: `maria.silva`) e se é administrador
(normalmente não). Isso cria a conta dele e agenda a remoção de qualquer outro
perfil que tenha sobrado (conta temporária do preparo, contas antigas de outras
pessoas etc.) para o próximo boot.

### 5. Pós-entrega
- Reiniciar (remove os perfis antigos e conclui a limpeza).
- Repassar a senha temporária do colaborador (também salva em
  `C:\OPN\Logs\colaborador-senha-temp.txt`, trocada obrigatoriamente no 1º login) e,
  no caso Pro, ele entra com a conta M365 no OneDrive/Office/Teams. **Apagar esse
  arquivo depois de repassar a senha.**
- Se algum perfil antigo foi removido, mover `C:\OPN\ProfileBackups\` (arquivos que
  pertenciam a essas contas) para o cofre da TI e só então apagar da máquina.
- Colar etiqueta física com o nome.

### 6. Registro
Preencher CHECKLIST-entrega.md, registrar no inventário, colher assinatura do termo.

## Problemas comuns
- *winget ausente:* abrir a Microsoft Store, atualizar "Instalador de Aplicativo"
  (ou https://aka.ms/getwinget), reexecutar.
- *OneDrive não logou (Home):* usuário abre o OneDrive e entra com a conta M365.
- *Wallpaper não travou:* reiniciar; se persistir, registrar a build no CHANGELOG.
- *BitLocker pulado:* sem TPM pronto; verificar TPM na BIOS/UEFI.
