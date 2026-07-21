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
& ([scriptblock]::Create($b)) -ComputerName OPN-CE-0042
```
O setup pede a **senha padrão da TI** do `opn-admin`, faz tudo e gera
`C:\OPN\Logs\setup-report.json`. **Reinicie ao final.**

### OOBE por edição
- **Pro:** "Configurar para trabalho/escola" → conta M365 do colaborador (Entra Join).
- **Home:** `Shift+F10` → `start ms-cxh:localonly` (builds antigos: `oobe\bypassnro`)
  → conta local (ex.: `setup-temp`). Se usar conta temporária, informe o nome dela em
  `organization.temporarySetupUser` para o setup agendar a remoção no próximo boot.

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
  `"OPN-CE-0042": ["OBSProject.OBSStudio"]`, suba a `version`, commit. Instala sozinho.

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
