@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ---------------------------------------------------------------------------
REM Estado del entorno: contenedores, DataNodes activos, nodos YARN y memoria.
REM
REM   scripts\status.bat
REM ---------------------------------------------------------------------------

REM Cambiar al directorio raiz del proyecto
cd /d "%~dp0.."

if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto.
    exit /b 1
)

REM Configuracion comun de Docker Compose
set "COMPOSE=-f docker-compose.yml -f docker-compose.datanodes.yml"
set "PROFILES=--profile full --profile dn2 --profile dn3"

echo.
echo === Contenedores del proyecto 'bigdata' ===
docker compose %COMPOSE% %PROFILES% ps

echo.
echo === DataNodes activos (HDFS: hdfs dfsadmin -report) ===
docker compose %COMPOSE% exec -T namenode bash -lc "hdfs dfsadmin -report 2>/dev/null | grep -E 'Live datanodes|Datanode Uuid|Name:'"

echo.
echo === Nodos de computo (YARN: yarn node -list) ===
docker compose %COMPOSE% exec -T yarnmaster bash -lc "yarn node -list 2>/dev/null"

echo.
echo === Memoria y CPU por contenedor (docker stats, uso observado) ===

REM Obtener los nombres de los contenedores en ejecucion
set "CONTAINERS="

for /f "usebackq delims=" %%N in (`docker compose %COMPOSE% %PROFILES% ps --format "{{.Name}}" 2^>nul`) do (
    if not "%%N"=="" set "CONTAINERS=!CONTAINERS! %%N"
)

REM Mostrar estadisticas si existen contenedores
setlocal EnableDelayedExpansion

if defined CONTAINERS (
    docker stats --no-stream --format "table {{.Name}} {{.MemUsage}} {{.CPUPerc}}" !CONTAINERS!
) else (
    echo No hay contenedores en ejecucion.
)

endlocal

echo.
echo Para el numero de DataNodes: busca 'Live datanodes (N)' arriba.

endlocal
