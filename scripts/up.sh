#!/usr/bin/env bash
#
# Levanta el entorno educativo.
#
#   ./scripts/up.sh                    # ligero: 1 DataNode (por defecto)
#   ./scripts/up.sh --datanodes 3      # ligero con 3 DataNodes
#   ./scripts/up.sh --full             # anade Hive + MySQL + Flume
#   ./scripts/up.sh --full --datanodes 2
#
set -euo pipefail
cd "$(dirname "$0")/.."

datanodes=1
full=0

while [ $# -gt 0 ]; do
  case "$1" in
    --datanodes) datanodes="${2:?falta el numero de DataNodes}"; shift 2 ;;
    --full)      full=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; exit 2 ;;
  esac
done

if ! [[ "$datanodes" =~ ^[0-9]+$ ]] || [ "$datanodes" -lt 1 ] || [ "$datanodes" -gt 3 ]; then
  echo "ERROR: --datanodes debe ser 1, 2 o 3" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "ERROR: no existe .env. Copia .env.example a .env y ajusta las credenciales." >&2
  echo "       cp .env.example .env" >&2
  exit 1
fi

compose=(docker compose -f docker-compose.yml -f docker-compose.datanodes.yml)
profiles=()
[ "$datanodes" -ge 2 ] && profiles+=(--profile dn2)
[ "$datanodes" -ge 3 ] && profiles+=(--profile dn3)
[ "$full" = "1" ]      && profiles+=(--profile full)

mode="ligera"; [ "$full" = "1" ] && mode="completa (Hive + MySQL + Flume)"
echo "==> Levantando entorno ${mode} con ${datanodes} DataNode(s)"

"${compose[@]}" "${profiles[@]}" up -d --wait --wait-timeout 900

# Reducir DataNodes conservando volumenes ("rm -sf" no borra el volumen).
for i in $(seq $((datanodes + 1)) 3); do
  "${compose[@]}" rm -sf "datanode$i" >/dev/null 2>&1 || true
done

"${compose[@]}" "${profiles[@]}" ps
