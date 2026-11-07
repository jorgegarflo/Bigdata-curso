#!/bin/bash

# Continuar ante errores (comportamiento por defecto en Bash, a menos que se use set -e)
# Obtiene el directorio padre de donde está el script
ROOT_DIR=$(dirname "$(dirname "$(readlink -f "$0")")")
cd "$ROOT_DIR" || exit

# Función equivalente a Invoke-Docker
invoke_docker() {
    # Redirige stderr a stdout (2>&1) para que se muestre en consola de forma unificada
    docker "$@" 2>&1
}

compose=("-f" "docker-compose.yml" "-f" "docker-compose.datanodes.yml")
allProfiles=("--profile" "full" "--profile" "dn2" "--profile" "dn3")

# Obtiene los IDs usando 'awk' para cortar la primera columna (columna 1)
containers=$(docker ps --format "{{.ID}}\t{{.Image}}" | grep "jgarciafl/" | awk '{print $1}')

# Si la variable containers no está vacía
if [ -n "$containers" ]; then
    echo -e "\e[36mDeteniendo del proyecto 'bigdata'...\e[0m"
    docker stop $containers
    
    echo -e "\e[36m=== Contenedores del proyecto 'bigdata' ===\e[0m"
    invoke_docker "compose" "${compose[@]}" "${allProfiles[@]}" "ps"
else
    echo -e "\e[36m=== Contenedores del proyecto 'bigdata' ===\e[0m"
    echo -e "\e[31mNo se encontraron contenedores activos.\e[0m"
fi
