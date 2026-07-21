# OPN Setup v2 — Padronização de computadores (O Pequeno Nazareno)

Transforma qualquer Windows 10/11 (**Home ou Pro**) numa máquina padrão da OPN:
apps, configurações, restrições, OneDrive com backup, criptografia e manutenção
diária autônoma. Sem Intune/SCCM/AD — só ferramentas nativas e gratuitas.

## Antes do primeiro uso (uma vez)
1. `config/settings.json`:
   - `organization.tenantId` → GUID do tenant (Entra admin center → Visão geral).
   - `repository.rawBase` e `repository.zipUrl` → URLs do SEU repositório.
   - `maintenance.heartbeatUrl` (opcional) → URL do Power Automate p/ inventário.
2. `bootstrap.ps1` → ajuste `$ZipUrl` (mesma de `repository.zipUrl`).
3. `assets/` → wallpaper.png, lockscreen.png.
4. Publique num GitHub **público** (não há segredos; a senha do admin nunca vai ao repo).

## Preparar uma máquina
PowerShell **como Administrador**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1 | iex
```
Com nome:
```powershell
$b = irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1
& ([scriptblock]::Create($b)) -ComputerName OPN-CE-PGG1
```
O setup pede só o **nome da máquina** e a **senha padrão da TI**. A partir disso:
- Cria `opn-admin` (conta da TI, administrador).
- Cria uma conta local **usuário padrão com o mesmo nome da máquina**
  (ex.: máquina `OPN-CE-PGG1` → usuário `OPN-CE-PGG1`) — é a conta de quem vai usar
  o computador no dia a dia. Sem Intune/Entra Join, o Windows não cria essa conta
  sozinho a partir da conta M365, então o setup cria na hora, com senha inicial
  gerada (troca obrigatória no 1º login, salva uma única vez em
  `C:\OPN\Logs\usuario-senha-inicial.txt`).
- Instala os apps, aplica as políticas e configurações.
- Agenda a remoção de **qualquer outro perfil** que tenha sobrado na máquina (a
  conta temporária usada para rodar o comando, contas antigas de laboratório/sala
  etc.) para o próximo boot — antes de apagar, copia Desktop/Documentos/Imagens de
  cada perfil removido para `C:\OPN\ProfileBackups\` (mova para o cofre da TI depois:
  sem `organization.tenantId` não há backup automático via OneDrive).

Gera `C:\OPN\Logs\setup-report.json`. **Reinicie ao final** para aplicar nome,
políticas e concluir a remoção dos perfis antigos.

### OOBE por edição
- **Pro:** "Configurar para trabalho/escola" → conta M365 do colaborador (Entra
  Join) já cria a conta dele — nesse caso a conta local `OPN-CE-PGG1` criada pelo
  setup fica sobrando e é removida como as demais no próximo boot.
- **Home:** `Shift+F10` → `start ms-cxh:localonly` (builds antigos: `oobe\bypassnro`)
  → qualquer conta local temporária (ex.: `setup-temp`) para rodar o comando. Ela é
  removida automaticamente no próximo boot.
- **Máquina já usada antes** (laboratório/sala, com contas de outras pessoas): pode
  logar direto numa das contas existentes e rodar o setup a partir dela — também
  será removida.

## Política de senha do admin (senha única da frota)
Decisão da OPN: **uma senha padrão** para o `opn-admin` em toda a frota
(`generateRandomAdminPassword: false`). Regras obrigatórias:
- Longa e exclusiva deste papel (nunca reutilizada em outro lugar).
- Guardada no cofre da TI (KeePass/Bitwarden).
- **Rotação a cada 6 meses** e **imediata** na saída de qualquer técnico ou suspeita.
  Rotação em massa: via Action1 empurre `net user opn-admin "NovaSenha"` — **nunca**
  coloque a senha no repositório.
- Trade-off aceito: um vazamento afeta a frota toda. Evolução recomendada (Fase 3):
  Windows LAPS (senha aleatória por máquina com escrow automático no Entra).

## Instalar um programa para um usuário específico
- **Pontual:** via AnyDesk, no UAC digite `opn-admin` + senha, ou `winget install --id X`.
- **Persistente (sobrevive a formatação):** em `applications.perMachine` adicione
  `"OPN-CE-PGG1": ["OBSProject.OBSStudio"]`, suba a `version`, commit. Instala sozinho.

## Dia a dia (mudanças na frota)
Edite o repositório e **aumente `version`** no settings.json → em até 24h todas as
máquinas se atualizam e reaplicam as políticas sozinhas.

## O que cada edição recebe
| Recurso | Home | Pro |
|---|---|---|
| Usuário padrão, winget, LibreOffice, OneDrive KFM, branding travado, energia, idioma, Explorer, restrições via registro, drivers, manutenção, inventário | ✔ | ✔ |
| BitLocker gerenciado + chave no Entra | — (Criptografia do Dispositivo, se suportada) | ✔ |

## Módulos
Common (log/registro/hives/relatório), Apps, System, Branding, OneDrive, Policies,
Security, Drivers, Inventory, Maintenance. Orquestrados por `OPN-Setup.ps1`.
