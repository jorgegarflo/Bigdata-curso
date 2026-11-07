param(
    [ValidateRange(1, 3)][int]$Count = 1,
    [switch]$Full
)

# ---------------------------------------------------------------------------
# Ajusta el numero de DataNodes del entorno (1, 2 o 3), conservando datos.
#
#   .\scripts\datanodes.ps1 -Count 2
#   .\scripts\datanodes.ps1 -Count 3
#   .\scripts\datanodes.ps1 -Count 1     # vuelve a la configuracion ligera
#
# Reducir el numero de DataNodes NO borra sus volumenes: al volver a
# arrancarlos recuperan sus bloques.  El registro de los nodos nuevos en el
# NameNode tarda unos segundos (los DataNodes se registran en cada latido).
# Comprueba el numero de nodos activos con:  .\scripts\status.ps1
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

& "$PSScriptRoot/up.ps1" -DataNodes $Count -NoBuild -Full:$Full
exit $LASTEXITCODE
