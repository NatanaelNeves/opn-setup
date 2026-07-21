<#
.SYNOPSIS
  OPN Setup - Fase 2 (entrega): cria a conta do colaborador e limpa perfis antigos.
.DESCRIPTION
  Rode isto DEPOIS do OPN-Setup.ps1 (Fase 1 - preparo), quando ja se sabe quem vai
  receber a maquina. Cria a conta local do colaborador (usuario padrao, senha
  temporaria com troca obrigatoria no 1o login) e agenda a remocao, no proximo boot,
  de qualquer outro perfil que tenha sobrado (conta temporaria de preparo, aluno ou
  usuario anterior etc.) - inclusive o perfil usado para rodar este script agora.
  Antes de apagar, faz backup local de Desktop/Documentos/Imagens de cada perfil
  removido em C:\OPN\ProfileBackups\ (sem organization.tenantId nao ha OneDrive
  automatico protegendo esses arquivos).
.EXAMPLE
  cd C:\OPN\Repository
  .\New-OPNUser.ps1
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Get-ChildItem "$Root\modules\*.psm1" | ForEach-Object { Import-Module $_.FullName -Force }

$Cfg = Get-Content "$Root\config\settings.json" -Raw | ConvertFrom-Json
Start-OPNLog -Path $Cfg.logging.path

Write-Host ''
Write-Host '=== Criar usuario do colaborador ===' -ForegroundColor Cyan
$fullName = Read-Host 'Nome completo'
$userName = Read-Host 'Usuario (ex.: maria.silva)'
if (-not $userName) { throw 'usuario e obrigatorio' }
$isAdmin = (Read-Host 'Administrador? (s/N)') -match '^[sS]'

$cred = Invoke-OPNStep 'Conta do colaborador' {
    New-OPNColaboradorAccount -UserName $userName -FullName $fullName -IsAdmin:$isAdmin
}

if ($cred) {
    $out = 'C:\OPN\Logs\colaborador-senha-temp.txt'
    New-Item (Split-Path $out) -ItemType Directory -Force | Out-Null
    "Maquina: $env:COMPUTERNAME`nUsuario: $($cred.UserName)`nSenha temporaria: $($cred.TempPassword)`n(trocada obrigatoriamente no 1o login)" |
        Set-Content $out
    Write-Host ''
    Write-Host '=== Credenciais (repasse ao colaborador e depois apague este bloco) ===' -ForegroundColor Yellow
    Write-Host "Usuario: $($cred.UserName)"
    Write-Host "Senha temporaria: $($cred.TempPassword)"
    Write-Host '(sera trocada obrigatoriamente no 1o login)'
    Write-Host "Tambem salva em: $out"
    Write-Host ''

    Invoke-OPNStep 'Limpeza de perfis antigos' {
        Remove-OPNStaleProfiles -AdminAccount $Cfg.organization.adminAccount -KeepUser $cred.UserName
    }
}

$null = Export-OPNReport -Path $Cfg.logging.path
Write-OPNLog 'CONCLUIDO. Reinicie a maquina para concluir a remocao dos perfis antigos.'
