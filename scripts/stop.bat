@echo off
setlocal enabledelayedexpansion

:: Obtiene el directorio padre (.. deshace un nivel desde el directorio del script)
cd /d "%~dp0.."

set "compose=-f docker-compose.yml -f docker-compose.datanodes.yml"
set "allProfiles=--profile full --profile dn2 --profile dn3"

:: Limpia la variable de contenedores
set "containers="

:: Ejecuta docker ps, filtra con findstr y corta la primera columna con FOR /F (delims=tab/espacio)
for /f "tokens=1" %%i in ('docker ps --format "{{.ID}}\t{{.Image}}" ^| findstr "jgarciafl/"') do (
    set "containers=!containers! %%i"
)

:: Si la variable containers tiene texto (eliminando espacios iniciales)
if not "!containers!"=="" (
    :: PowerShell usaba colores, en CMD nativo usamos texto limpio o comandos echo alternativos
    echo Deteniendo del proyecto 'bigdata'...
    docker stop !containers!
    
    echo === Contenedores del proyecto 'bigdata' ===
    :: Ejecutamos redirigiendo el error 2>&1
    docker compose %compose% %allProfiles% ps 2>&1
) else (
    echo === Contenedores del proyecto 'bigdata' ===
    echo No se encontraron contenedores activos.
)

endlocal
