
@echo off
setlocal EnableExtensions

rem ===========================================================================
rem Levanta el entorno educativo Hadoop.
rem
rem Uso:
rem   scripts\up.bat
rem   scripts\up.bat --DataNodes 3
rem   scripts\up.bat --Full
rem   scripts\up.bat --Full --DataNodes 2
rem   scripts\up.bat --WaitTimeout 1200
rem
rem Opciones:
rem   --DataNodes N    Numero de DataNodes: 1, 2 o 3 (por defecto: 1)
rem   --Full           Anade Hive + MySQL + Flume
rem   --WaitTimeout N  Espera maxima en segundos (por defecto: 900)
rem ===========================================================================

set "DATANODES=1"
set "FULL=0"
set "WAITTIMEOUT=900"

rem Resolver la raiz del proyecto a partir de la ubicacion de este BAT.
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%" || exit /b 1

rem ---------------------------------------------------------------------------
rem Procesar argumentos
rem ---------------------------------------------------------------------------

:parse
if "%~1"=="" goto parsed

if /i "%~1"=="--DataNodes" goto parse_datanodes
if /i "%~1"=="-DataNodes" goto parse_datanodes

if /i "%~1"=="--Full" (
    set "FULL=1"
    shift
    goto parse
)
if /i "%~1"=="-Full" (
    set "FULL=1"
    shift
    goto parse
)

if /i "%~1"=="--WaitTimeout" goto parse_timeout
if /i "%~1"=="-WaitTimeout" goto parse_timeout

echo ERROR: Parametro desconocido: %~1
goto usage_error

:parse_datanodes
if "%~2"=="" (
    echo ERROR: Falta el numero de DataNodes.
    goto usage_error
)
set "DATANODES=%~2"
shift
shift
goto parse

:parse_timeout
if "%~2"=="" (
    echo ERROR: Falta el tiempo de espera.
    goto usage_error
)
set "WAITTIMEOUT=%~2"
shift
shift
goto parse

:parsed

rem ---------------------------------------------------------------------------
rem Validar parametros
rem ---------------------------------------------------------------------------

if "%DATANODES%"=="1" goto datanodes_ok
if "%DATANODES%"=="2" goto datanodes_ok
if "%DATANODES%"=="3" goto datanodes_ok

echo ERROR: DataNodes debe ser 1, 2 o 3.
goto usage_error

:datanodes_ok
set "TIMEOUT_VALID=0"
for /f "delims=0123456789" %%A in ("%WAITTIMEOUT%") do set "TIMEOUT_VALID=1"
if "%WAITTIMEOUT%"=="" set "TIMEOUT_VALID=1"
if "%TIMEOUT_VALID%"=="1" (
    echo ERROR: WaitTimeout debe ser un numero entero positivo.
    goto usage_error
)
if %WAITTIMEOUT% LEQ 0 (
    echo ERROR: WaitTimeout debe ser mayor que cero.
    goto usage_error
)

rem ---------------------------------------------------------------------------
rem Comprobar .env
rem ---------------------------------------------------------------------------

if not exist ".env" (
    echo ERROR: No existe el archivo .env.
    echo Copia .env.example a .env y configura las credenciales locales.
    echo.
    echo Comando:
    echo   copy .env.example .env
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Configurar Docker Compose y perfiles
rem ---------------------------------------------------------------------------

set "COMPOSE=-f docker-compose.yml -f docker-compose.datanodes.yml"
set "PROFILES="

if %DATANODES% GEQ 2 set "PROFILES=%PROFILES% --profile dn2"
if %DATANODES% GEQ 3 set "PROFILES=%PROFILES% --profile dn3"
if "%FULL%"=="1" set "PROFILES=%PROFILES% --profile full"

if "%FULL%"=="1" (
    set "MODE=completa (Hive + MySQL + Flume)"
) else (
    set "MODE=ligera"
)

echo.
echo ============================================================
echo Levantando entorno %MODE%
echo DataNodes: %DATANODES%
echo Tiempo maximo de espera: %WAITTIMEOUT% segundos
echo ============================================================
echo.

rem ---------------------------------------------------------------------------
rem Arrancar los servicios y esperar a que esten disponibles.
rem ---------------------------------------------------------------------------

docker compose %COMPOSE% %PROFILES% up -d --wait --wait-timeout %WAITTIMEOUT%
if errorlevel 1 (
    echo.
    echo ERROR: Docker Compose no ha podido arrancar el entorno.
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Detener y eliminar los DataNodes sobrantes.
rem Se conservan sus volumenes para reutilizar sus datos posteriormente.
rem ---------------------------------------------------------------------------

if %DATANODES% LSS 2 (
    call :remove_node 2
    if errorlevel 1 exit /b 1
)
if %DATANODES% LSS 3 (
    call :remove_node 3
    if errorlevel 1 exit /b 1
)

rem ---------------------------------------------------------------------------
rem Mostrar estado final
rem ---------------------------------------------------------------------------

echo.
echo ^>^>^> Estado final de los servicios:
docker compose %COMPOSE% %PROFILES% ps
if errorlevel 1 (
    echo ERROR: No se pudo consultar el estado de los servicios.
    exit /b 1
)

echo.
echo Entorno iniciado correctamente.
exit /b 0

:remove_node
docker compose %COMPOSE% rm -sf datanode%~1
if errorlevel 1 (
    echo ERROR: No se pudo eliminar el contenedor datanode%~1.
    exit /b 1
)
exit /b 0

:usage_error
echo.
echo Uso:
echo   up.bat [--DataNodes 1^|2^|3] [--Full] [--WaitTimeout segundos]
exit /b 2
