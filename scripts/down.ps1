param(
    [switch]$Volumes
)

# ---------------------------------------------------------------------------
# Detiene el entorno.
#
#   .\scripts\down.ps1            # para y elimina contenedores/red, CONSERVA datos
#   .\scripts\down.ps1 -Volumes   # ADEMAS borra los volumenes (pide confirmacion)
#
# Sin -Volumes NO se ejecuta "down -v": los volumenes namenode-data,
# datanode*-data y mysql-data se conservan intactos.
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

$compose = @("-f", "docker-compose.yml", "-f", "docker-compose.datanodes.yml")
$profiles = @("--profile", "full", "--profile", "dn2", "--profile", "dn3")

if ($Volumes) {
    Write-Host "AVISO: se van a ELIMINAR los volumenes (metadatos HDFS de namenode," -ForegroundColor Red
    Write-Host "       bloques de los DataNodes y base de datos del metastore)." -ForegroundColor Red
    Write-Host "       Los datos NO podran recuperarse con este procedimiento." -ForegroundColor Red
    if ([Console]::IsInputRedirected) {
        Write-Host "Entrada no interactiva: borrar volumenes requiere confirmacion interactiva." -ForegroundColor Yellow
        exit 1
    }
    $answer = Read-Host "Escribe 'BORRAR' para confirmar"
    if ($answer -ne "BORRAR") {
        Write-Host "Cancelado."
        exit 1
    }
    Invoke-Docker (@("compose") + $compose + $profiles + @("down", "-v"))
} else {
    Invoke-Docker (@("compose") + $compose + $profiles + @("down"))
}
exit $script:DockerExitCode
