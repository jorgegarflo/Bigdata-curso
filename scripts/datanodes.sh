#!/usr/bin/env bash
#
# Ajusta el numero de DataNodes del entorno (1, 2 o 3), conservando datos.
#
#   ./scripts/datanodes.sh 2
#   ./scripts/datanodes.sh 3
#   ./scripts/datanodes.sh 1        # vuelve a la configuracion ligera
#   ./scripts/datanodes.sh 2 --full # manteniendo tambien los servicios avanzados
#
set -euo pipefail

count="${1:-1}"
shift || true

# Reducir DataNodes no borra volumenes; los nodos nuevos tardan unos segundos
# en registrarse en el NameNode.  Estado: ./scripts/status.sh
exec "$(dirname "$0")/up.sh" --datanodes "$count" --no-build "$@"
