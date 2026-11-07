$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Ejecuta docker mostrando la salida en consola (no se captura como valor de
# retorno).  Necesario en Windows para que el stderr de Docker no rompa el
# script ni contamine variables.
function Invoke-Docker {
    param([string[]]$Arguments)
    & docker @Arguments 2>&1 | ForEach-Object { Write-Host "$_" }
}


$compose = @("-f", "docker-compose.yml", "-f", "docker-compose.datanodes.yml")
$allProfiles = @("--profile", "full", "--profile", "dn2", "--profile", "dn3")

# Obtiene los IDs de los contenedores en ejecución cuya imagen comience por jgarciafl/
$containers = docker ps --format "{{.ID}}\t{{.Image}}" | Select-String "jgarciafl/" | ForEach-Object { ($_ -split '\s+')[0] }

if ($containers) {
    Write-Host "Deteniendo del proyecto 'bigdata'..." -ForegroundColor Cyan
    docker stop $containers    
    Write-Host "=== Contenedores del proyecto 'bigdata' ===" -ForegroundColor Cyan
    Invoke-Docker (@("compose") + $compose + $allProfiles + @("ps"))
} else {
    Write-Host "=== Contenedores del proyecto 'bigdata' ===" -ForegroundColor Cyan
    Write-Host "No se encontraron contenedores activos." -ForegroundColor red
}
