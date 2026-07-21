# CHANGELOG

## 1.0.4
- Novo `New-OPNUser.ps1`: separa o fluxo em **Preparo** (`OPN-Setup.ps1`, não cria
  conta de colaborador — na hora do preparo a TI geralmente ainda não sabe quem vai
  receber a máquina) e **Entrega** (`New-OPNUser.ps1`, rodado depois, quando já se
  sabe). Fica disponível em `C:\OPN\Repository\New-OPNUser.ps1` assim que o preparo
  copia o repositório para a máquina.
- `New-OPNUser.ps1` pergunta nome completo, usuário e se é administrador; cria a
  conta local do colaborador com senha temporária forçada a trocar no 1º login, e
  agenda a remoção, no próximo boot, de QUALQUER outro perfil que tenha sobrado
  (conta temporária do preparo, aluno/usuário anterior etc.), inclusive o que está
  rodando o comando agora — com backup local prévio de Desktop/Documentos/Imagens em
  `C:\OPN\ProfileBackups\` (não há OneDrive automático sem `tenantId` para proteger
  esses arquivos).
- Removidos os campos `organization.temporarySetupUser` e `removeTemporarySetupUser`
  do settings.json — não fazem mais falta, a limpeza agora é automática e cobre
  qualquer perfil, não só um nome fixo configurado antes.
- `Set-OPNStandardUsers` não precisa mais do parâmetro de conta temporária: mantém
  como admin, além da conta da TI, quem estiver rodando o script no momento (será
  removido de qualquer forma no próximo boot pela limpeza de perfis, se não for o
  colaborador informado em `New-OPNUser.ps1`).

## 1.0.3
- "Idioma e região" não aborta mais tudo se um item falhar isoladamente (ex.: fuso
  horário ausente em imagens de Windows reduzidas) — cada item agora loga aviso e
  segue, igual já acontecia com Set-Culture.
- Escrita de configurações do Explorer na sessão atual também não derruba mais o
  restante do passo em caso de erro (mesmo tratamento já usado nos outros perfis).
- Falha de instalação via winget agora registra a última linha da saída real do
  winget no log, não só o código — facilita diagnosticar por que um pacote falhou.

## 1.0.2
- Corrigido: em Windows pt-BR o grupo local "Administrators" chama-se "Administradores",
  o que quebrava a criação da conta opn-admin e o rebaixamento de usuários. Agora o grupo
  é resolvido pelo SID (S-1-5-32-544), independente do idioma.
- Corrigido: winget podia falhar (código 0x8A15000F) na primeira execução em uma conta
  recém-criada, por falta de cache de fontes; agora rodamos `winget source update` antes
  de instalar.
- `organization.computerPattern` agora aceita código livre depois da UF
  (ex.: `OPN-CE-PGG1`), não só 4 dígitos.

## 1.0.1
- Removido Office via ODT (exigia licença Business Standard/Premium que a
  equipe não tem) e GPO local via LGPO (recurso avançado sem uso). Máquinas
  agora recebem LibreOffice (gratuito) via winget, como qualquer outro app.

## 1.0.0
- Versão inicial v2 alinhada ao settings.json da OPN.
- Módulos: Common, Apps, System, Branding, OneDrive, Policies, Security,
  Drivers, Inventory, Maintenance.
- Senha única da TI (generateRandomAdminPassword=false).
- Remoção agendada da conta temporária de setup.
- Comparação de versão por semver ([version]).
- Políticas por usuário (regedit/painel/CMD) poupando a conta da TI.
- Drivers por fabricante (Dell/Lenovo/HP), apps opcionais e por máquina.
- Inventário com heartbeat; limpeza de logs por logging.keepDays.
