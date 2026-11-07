@echo off
setlocal EnableExtensions

REM ---------------------------------------------------------------------------
REM Reinicializacion COMPLETA (destructiva) del entorno de practicas.
REM
REM   scripts\reset.bat       - pide confirmacion escribiendo BORRAR
REM   scripts\reset.bat -Yes  - sin preguntar (solo para automatizacion)
REM ---------------------------------------------------------------------------

REM Cambiar al directorio raiz del proyecto
cd /d "%~dp0.."

if errorlevel 1 (
    echo ERROR: No se puede acceder al directorio del proyecto.
    exit /b 1
)

echo.
echo ============================================================
echo ATENCION: ESTA OPERACION ES DESTRUCTIVA
echo ============================================================
echo.
echo Este script DESTRUYE todos los datos del entorno:
echo   - Metadatos del NameNode (volumen namenode-data)
echo   - Datos de los DataNodes (volumenes datanode1..3-data)
echo   - Base de datos del metastore (volumen mysql-data)
echo.
echo Los datos NO podran recuperarse con este procedimiento.
echo.

REM Comprobar si se ha indicado el modo no interactivo
if /i "%~1"=="-Yes" goto confirmacion_automatica

REM Solicitar confirmacion explicita
set /p "ANSWER=Escribe BORRAR para confirmar la reinicializacion completa: "

if not "%ANSWER%"=="BORRAR" (
    echo.
    echo Cancelado.
    exit /b 1
)

goto ejecutar_reset

:confirmacion_automatica
echo Modo automatico: se omite la confirmacion.
echo.

:ejecutar_reset
echo.
echo Eliminando contenedores y volumenes del entorno...
echo.

docker compose -f docker-compose.yml -f docker-compose.datanodes.yml --profile full --profile dn2 --profile dn3 down -v --remove-orphans

if errorlevel 1 (
    echo.
    echo ERROR: Docker Compose no pudo completar la operacion.
    exit /b 1
)

echo.
echo Entorno eliminado correctamente.
echo El siguiente scripts\up.bat creara un HDFS vacio.
echo.

endlocal
