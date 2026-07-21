# OPN.Drivers.psm1 - Instala o utilitario de atualizacao de drivers do fabricante.

function Install-OPNDriverTool {
    param([Parameter(Mandatory)]$Drivers)
    if (-not $Drivers.detectManufacturer) { Write-OPNLog '  drivers.detectManufacturer = false'; return }
    $mfg = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    Write-OPNLog "  fabricante detectado: $mfg"
    $id = $null
    switch -Regex ($mfg) {
        'Dell'          { if ($Drivers.dell)   { $id = 'Dell.CommandUpdate' } }
        'LENOVO|Lenovo' { if ($Drivers.lenovo) { $id = 'Lenovo.SystemUpdate' } }
        'HP|Hewlett'    { if ($Drivers.hp)     { $id = 'HP.HPSupportAssistant' } }
        default         { Write-OPNLog '  fabricante sem utilitario mapeado - Windows Update cobre drivers basicos' }
    }
    if (-not $id) { return }
    winget list --id $id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Write-OPNLog "  $id ja instalado"; return }
    winget install --id $id --exact --silent --scope machine `
        --accept-package-agreements --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-OPNLog "  nao foi possivel instalar $id via winget - instale manualmente se necessario" 'WARN'
    } else { Write-OPNLog "  instalado: $id" }
}

Export-ModuleMember -Function Install-OPNDriverTool
