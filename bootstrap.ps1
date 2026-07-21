<#
.SYNOPSIS
  Bootstrap do OPN Setup - unica linha que a TI decora.
.DESCRIPTION
  Baixa o pacote atual do repositorio, extrai para C:\OPN\Repository e executa o setup.
  PowerShell como Administrador:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1 | iex
  Com parametros:
    $b = irm https://raw.githubusercontent.com/NatanaelNeves/opn-setup/main/bootstrap.ps1
    & ([scriptblock]::Create($b)) -ComputerName OPN-CE-0042
#>
param([string]$ComputerName)
$ErrorActionPreference = 'Stop'

$ZipUrl = 'https://codeload.github.com/NatanaelNeves/opn-setup/zip/refs/heads/main'
$Repo   = 'C:\OPN\Repository'

Write-Host '== OPN Bootstrap: baixando pacote...' -ForegroundColor Cyan
New-Item 'C:\OPN' -ItemType Directory -Force | Out-Null
$zip = Join-Path $env:TEMP 'opn-setup.zip'
$tmp = Join-Path $env:TEMP 'opn-setup-extract'
Invoke-WebRequest $ZipUrl -OutFile $zip -UseBasicParsing
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive $zip $tmp -Force
$inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
Remove-Item $Repo -Recurse -Force -ErrorAction SilentlyContinue
New-Item $Repo -ItemType Directory -Force | Out-Null
Copy-Item "$($inner.FullName)\*" $Repo -Recurse -Force
Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host '== OPN Bootstrap: executando setup...' -ForegroundColor Cyan
& "$Repo\OPN-Setup.ps1" -ComputerName $ComputerName
