#!/usr/bin/env bash
#
# Estado del entorno: contenedores, DataNodes activos, nodos YARN y memoria.
#
set -uo pipefail
cd "$(dirname "$0")/.."

compose=(docker compose -f docker-compose.yml -f docker-compose.datanodes.yml)
allProfiles=(--profile full --profile dn2 --profile dn3)

echo "=== Contenedores del proyecto 'bigdata' ==="
"${compose[@]}" "${allProfiles[@]}" ps

echo ""
echo "=== DataNodes activos (HDFS) ==="
"${compose[@]}" exec -T namenode bash -lc "hdfs dfsadmin -report 2>/dev/null | grep -E 'Live datanodes|Datanode Uuid|Name:'" 2>/dev/null

echo ""
echo "=== Nodos de computo (YARN) ==="
"${compose[@]}" exec -T yarnmaster bash -lc "yarn node -list 2>/dev/null" 2>/dev/null

echo ""
echo "=== Memoria y CPU por contenedor (docker stats) ==="
names="$("${compose[@]}" "${allProfiles[@]}" ps --format '{{.Name}}' 2>/dev/null | tr '\n' ' ')"
if [ -n "${names// /}" ]; then
  # shellcheck disable=SC2086
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" $names
else
  echo "No hay contenedores en ejecucion."
fi
