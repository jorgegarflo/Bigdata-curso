#!/usr/bin/env bash
# Detiene el entorno. Con --volumes elimina tambien los datos (pide confirmacion).
#
# Sin --volumes NO se usa "down -v": los volumenes persistentes se conservan.
set -euo pipefail
cd "$(dirname "$0")/.."

compose=(docker compose -f docker-compose.yml -f docker-compose.datanodes.yml)
profiles=(--profile full --profile dn2 --profile dn3)

if [ "${1:-}" = "--volumes" ]; then
  cat <<'EOF'
AVISO: se ELIMINARAN los volumenes:
  - metadatos de HDFS (namenode-data)
  - bloques de los DataNodes (datanode1..3-data)
  - base de datos del metastore (mysql-data)
Los datos NO podran recuperarse con este procedimiento.
EOF
  read -r -p "Escribe 'BORRAR' para confirmar: " answer || { echo "Entrada no interactiva: cancelado." >&2; exit 1; }
  [ "$answer" = "BORRAR" ] || { echo "Cancelado."; exit 1; }
  "${compose[@]}" "${profiles[@]}" down -v
else
  "${compose[@]}" "${profiles[@]}" down
fi
