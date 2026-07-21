# CHANGELOG

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
