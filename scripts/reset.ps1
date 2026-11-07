param(
    [switch]$Yes
)

# ---------------------------------------------------------------------------
# Reinicializacion COMPLETA (destructiva) del entorno de practicas.
#
#   .\scripts\reset.ps1        # pide confirmacion escribiendo BORRAR
#   .\scripts\reset.ps1 -Yes   # sin preguntar (solo para automatizacion)
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Docker {
    param([string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & docker @Arguments 2>&1 | ForEach-Object { Write-Host "$_" }
        $script:DockerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prev
    }
}

Write-Host "Este script DESTRUYE todos los datos del entorno:" -ForegroundColor Red
Write-Host "  - metadatos del NameNode (volumen namenode-data)" -ForegroundColor Red
Write-Host "  - datos de los DataNodes (volumenes datanode1..3-data)" -ForegroundColor Red
Write-Host "  - base de datos del metastore (volumen mysql-data)" -ForegroundColor Red
Write-Host "Los datos NO podran recuperarse con este procedimiento." -ForegroundColor Red
Write-Host ""

if (-not $Yes) {
    if ([Console]::IsInputRedirected) {
        Write-Host "Entrada no interactiva: para confirmar la reinicializacion usa -Yes." -ForegroundColor Yellow
        exit 1
    }
    $answer = Read-Host "Escribe 'BORRAR' para confirmar la reinicializacion completa"
    if ($answer -ne "BORRAR") {
        Write-Host "Cancelado."
        exit 1
    }
}

Invoke-Docker @("compose", "-f", "docker-compose.yml", "-f", "docker-compose.datanodes.yml",
    "--profile", "full", "--profile", "dn2", "--profile", "dn3",
    "down", "-v", "--remove-orphans")
if ($script:DockerExitCode -ne 0) { exit 1 }

Write-Host "Entorno eliminado. El siguiente 'scripts/up.ps1' creara un HDFS vacio."
