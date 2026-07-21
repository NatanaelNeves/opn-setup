# CHANGELOG

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
