# ---------------------------------------------------------------------------
# Estado del entorno: contenedores, DataNodes activos, nodos YARN y memoria.
#
#   .\scripts\status.ps1
# ---------------------------------------------------------------------------

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

Write-Host "=== Contenedores del proyecto 'bigdata' ===" -ForegroundColor Cyan
Invoke-Docker (@("compose") + $compose + $allProfiles + @("ps"))

Write-Host "`n=== DataNodes activos (HDFS: hdfs dfsadmin -report) ===" -ForegroundColor Cyan
Invoke-Docker (@("compose") + $compose + @("exec", "-T", "namenode", "bash", "-lc",
    "hdfs dfsadmin -report 2>/dev/null | grep -E 'Live datanodes|Datanode Uuid|Name:'"))

Write-Host "`n=== Nodos de computo (YARN: yarn node -list) ===" -ForegroundColor Cyan
Invoke-Docker (@("compose") + $compose + @("exec", "-T", "yarnmaster", "bash", "-lc",
    "yarn node -list 2>/dev/null"))

Write-Host "`n=== Memoria y CPU por contenedor (docker stats, uso observado) ===" -ForegroundColor Cyan
$names = @()
& docker compose @compose @allProfiles ps --format "{{.Name}}" 2>$null | ForEach-Object { if ($_) { $names += "$_" } }
if ($names.Count -gt 0) {
    Invoke-Docker (@("stats", "--no-stream", "--format", "table {{.Name}} {{.MemUsage}} {{.CPUPerc}}") + $names)
} else {
    Write-Host "No hay contenedores en ejecucion."
}

Write-Host ""
Write-Host "Para el numero de DataNodes: busca 'Live datanodes (N)' arriba." -ForegroundColor DarkGray
