@echo off
setlocal EnableExtensions

REM ---------------------------------------------------------------------------
REM Ajusta el numero de DataNodes del entorno (1, 2 o 3), conservando datos.
REM
REM   scripts\datanodes.bat -Count 2
REM   scripts\datanodes.bat -Count 3
REM   scripts\datanodes.bat -Count 1
REM   scripts\datanodes.bat -Count 3 -Full
REM
REM Reducir el numero de DataNodes NO borra sus volumenes: al volver a
REM arrancarlos recuperan sus bloques.
REM El registro de nodos nuevos en el NameNode tarda unos segundos.
REM Comprueba los nodos activos con: scripts\status.bat
REM ---------------------------------------------------------------------------

set "COUNT=1"
set "FULL="

:parse_args
if "%~1"=="" goto validate

if /i "%~1"=="-Count" (
    if "%~2"=="" (
        echo ERROR: Falta el valor de -Count.
        exit /b 1
    )
    set "COUNT=%~2"
    shift
    shift
    goto parse_args
)

if /i "%~1"=="-Full" (
    set "FULL=-Full"
    shift
    goto parse_args
)

echo ERROR: Parametro desconocido: %~1
echo Uso: scripts\datanodes.bat [-Count 1^|2^|3] [-Full]
exit /b 1


:validate
if "%COUNT%"=="1" goto run
if "%COUNT%"=="2" goto run
if "%COUNT%"=="3" goto run

echo ERROR: -Count debe ser 1, 2 o 3.
exit /b 1


:run
echo Ajustando el entorno a %COUNT% DataNode(s)...

call "%~dp0\scripts\up.bat" -DataNodes %COUNT% %FULL%
set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%
