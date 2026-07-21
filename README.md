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

## Preparar uma máquina (Preparo)
Na hora do preparo a TI geralmente ainda não sabe quem vai receber a máquina — por
isso o preparo **não cria conta de colaborador**, só deixa a máquina pronta.

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
O setup pede o **nome da máquina** e a **senha padrão da TI**, cria a conta
`opn-admin`, instala/configura tudo e gera `C:\OPN\Logs\setup-report.json`.
**Reinicie ao final** para aplicar nome e políticas.

### OOBE por edição
- **Pro:** "Configurar para trabalho/escola" → conta M365 do colaborador (Entra Join);
  essa conta já existe quando o setup roda, não precisa criar nada na entrega.
- **Home:** `Shift+F10` → `start ms-cxh:localonly` (builds antigos: `oobe\bypassnro`)
  → qualquer conta local temporária (ex.: `setup-temp`). Ela é removida
  automaticamente na entrega (próxima seção), não precisa fazer nada agora.
- **Máquina já usada antes** (laboratório/sala, com contas de outras pessoas): pode
  logar direto numa das contas existentes e rodar o preparo a partir dela — também
  será removida na entrega.

## Entregar a máquina a alguém (Entrega)
Quando já se sabe quem vai receber a máquina, no mesmo PowerShell como Administrador:
```powershell
cd C:\OPN\Repository
.\New-OPNUser.ps1
```
Pede **nome completo**, **usuário** (ex.: `maria.silva`) e se é administrador
(normalmente não). Cria a conta local do colaborador (usuário padrão, senha
temporária com troca obrigatória no 1º login) e agenda a remoção, no próximo boot, de
**qualquer outro perfil** que tenha sobrado — conta temporária do OOBE, contas de
alunos/usuários anteriores etc., inclusive a que está rodando o comando agora. Antes
de apagar, copia Desktop/Documentos/Imagens de cada perfil removido para
`C:\OPN\ProfileBackups\` (mova para o cofre da TI depois: sem `organization.tenantId`
não há backup automático via OneDrive). **Reinicie ao final.**

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
