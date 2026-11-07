#!/usr/bin/env bash
# Reinicializacion COMPLETA (destructiva) del entorno de practicas.
set -euo pipefail
cd "$(dirname "$0")/.."

cat <<'EOF'
Este script DESTRUYE todos los datos del entorno:
  - metadatos del NameNode (volumen namenode-data)
  - datos de los DataNodes (volumenes datanode1..3-data)
  - base de datos del metastore (volumen mysql-data)
Los datos NO podran recuperarse con este procedimiento.
EOF

confirm=0
[ "${1:-}" = "--yes" ] && confirm=1

if [ "$confirm" != "1" ]; then
  if ! read -r -p "Escribe 'BORRAR' para confirmar la reinicializacion completa: " answer; then
    echo "Entrada no interactiva: para confirmar usa --yes." >&2
    exit 1
  fi
  [ "$answer" = "BORRAR" ] || { echo "Cancelado."; exit 1; }
fi

docker compose -f docker-compose.yml -f docker-compose.datanodes.yml \
  --profile full --profile dn2 --profile dn3 down -v --remove-orphans
echo "Entorno eliminado. El siguiente 'scripts/up.sh' creara un HDFS vacio."
