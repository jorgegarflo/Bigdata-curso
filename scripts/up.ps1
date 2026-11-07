param(
    [ValidateRange(1, 3)][int]$DataNodes = 1,
    [switch]$Full,
    [int]$WaitTimeout = 900
)

# ---------------------------------------------------------------------------
# Levanta el entorno educativo.
#
#   .\scripts\up.ps1                     # ligero: 1 DataNode (por defecto)
#   .\scripts\up.ps1 -DataNodes 3        # ligero con 3 DataNodes
#   .\scripts\up.ps1 -Full               # anade Hive + MySQL + Flume
#   .\scripts\up.ps1 -Full -DataNodes 2  # todo, con 2 DataNodes
#
# El perfil "full" arranca los servicios avanzados (Hive, MySQL, Flume); el
# resto es la configuracion ligera pensada para equipos con 16 GB de RAM.
#
# Nota (Windows): el progreso de Docker va a stderr y con
# $ErrorActionPreference = "Stop" dispararia un NativeCommandError.  El helper
# Invoke-Docker ejecuta docker con ErrorActionPreference="Continue" durante la
# llamada, escribe la salida con Write-Host y deja el codigo en
# $script:DockerExitCode.
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

if (-not (Test-Path ".env")) {
    Write-Error "No existe .env. Copia .env.example a .env y ajusta las credenciales locales:  Copy-Item .env.example .env"
    exit 1
}

$compose = @("-f", "docker-compose.yml", "-f", "docker-compose.datanodes.yml")

$profileArgs = @()
if ($DataNodes -ge 2) { $profileArgs += @("--profile", "dn2") }
if ($DataNodes -ge 3) { $profileArgs += @("--profile", "dn3") }
if ($Full)           { $profileArgs += @("--profile", "full") }

$mode = if ($Full) { "completa (Hive + MySQL + Flume)" } else { "ligera" }
Write-Host "==> Levantando entorno $mode con $DataNodes DataNode(s)"

$upCmd = @("compose") + $compose + $profileArgs + @("up", "-d", "--wait", "--wait-timeout", "$WaitTimeout")
Invoke-Docker $upCmd
if ($script:DockerExitCode -ne 0) { exit 1 }

# Reducir el numero de DataNodes si habia mas de los pedidos.
# "rm -sf" para y elimina el CONTENEDOR, pero CONSERVA su volumen: al volver a
# arrancarlo, el DataNode recupera sus bloques.
for ($i = $DataNodes + 1; $i -le 3; $i++) {
    $rmCmd = @("compose") + $compose + @("rm", "-sf", "datanode$i")
    Invoke-Docker $rmCmd
}

$psCmd = @("compose") + $compose + $profileArgs + @("ps")
Invoke-Docker $psCmd
