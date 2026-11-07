@echo off
setlocal EnableExtensions

REM ---------------------------------------------------------------------------
REM Detiene el entorno.
REM
REM   scripts\down.bat            - para y elimina contenedores/red, CONSERVA datos
REM   scripts\down.bat -Volumes   - ADEMAS borra los volumenes (pide confirmacion)
REM
REM Sin -Volumes NO se utiliza "down -v": los volumenes namenode-data,
REM datanode*-data y mysql-data se conservan intactos.
REM ---------------------------------------------------------------------------

REM Cambiar al directorio raiz del proyecto
cd /d "%~dp0.."

if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto.
    exit /b 1
)

set "COMPOSE=-f docker-compose.yml -f docker-compose.datanodes.yml"
set "PROFILES=--profile full --profile dn2 --profile dn3"

REM Comprobar si se ha solicitado eliminar los volumenes
if /i "%~1"=="-Volumes" goto borrar_volumenes

goto detener_entorno


:borrar_volumenes
echo.
echo ============================================================
echo AVISO: SE VAN A ELIMINAR LOS VOLUMENES
echo ============================================================
echo.
echo Se eliminaran:
echo   - Metadatos HDFS del NameNode
echo   - Bloques de datos de los DataNodes
echo   - Base de datos del metastore
echo.
echo Los datos NO podran recuperarse con este procedimiento.
echo.

REM Comprobar si existe una consola interactiva
echo %CMDCMDLINE% | findstr /i /c:"/c" >nul

REM Solicitar confirmacion explicita
set /p "ANSWER=Escribe BORRAR para confirmar: "

if not "%ANSWER%"=="BORRAR" (
    echo.
    echo Cancelado.
    exit /b 1
)

echo.
echo Eliminando contenedores, red y volumenes...
echo.

docker compose %COMPOSE% %PROFILES% down -v
set "DOCKER_EXIT=%ERRORLEVEL%"
goto finalizar


:detener_entorno
echo.
echo Deteniendo el entorno y conservando los volumenes...
echo.

docker compose %COMPOSE% %PROFILES% down
set "DOCKER_EXIT=%ERRORLEVEL%"
goto finalizar


:finalizar
if not "%DOCKER_EXIT%"=="0" (
    echo.
    echo ERROR: Docker Compose ha devuelto el codigo %DOCKER_EXIT%.
)

endlocal & exit /b %DOCKER_EXIT%
