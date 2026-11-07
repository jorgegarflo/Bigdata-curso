# Arquitectura del entorno

## 1. Imágenes

| Imagen local | Contexto de construcción | Contenido | Servicios que la usan |
|---|---|---|---|
| `jgarciafl/hadoop:3.5.0` | `hadoop/` | Ubuntu 24.04, OpenJDK 17, Hadoop 3.5.0, Python 3 (venv con `mrjob`, `avro`, `pymysql`), scripts de arranque | `datanode1..3` |
| `jgarciafl/hive-cliente:3.5.0` | `namenode-cliente/` | base + Hive + Pig + Flume + Sqoop + conector JDBC + datasets + `tools/sql_hdfs.py` | `namenode`, `hive-server` |
| `jgarciafl/yarnmaster:3.5.0` | `yarnmaster/` | base (solo `ROLE=resourcemanager`) | `yarnmaster` |
| `jgarciafl/flume-agent:3.5.0` | `flume-agent/` | base + Flume | `flume-agent` |
| `jgarciafl/jupyter:3.5.0` | `jupyter/` | base + `notebook` 7 + `pandas` + **spaCy 3.7.5 + `es_core_news_sm` 3.7.0** | `jupyter` |
| `mysql:8.0` | (Docker Hub) | MySQL 8 LTS | `hive-metastore-db` |

Se reutiliza una **única imagen base** para no repetir la descarga de Hadoop
(≈1 GB) en varias imágenes. La imagen `hive-cliente` se comparte entre
`namenode` y `hive-server` por el mismo motivo: no tiene sentido descargar
Hive/Pig/Flume/Sqoop dos veces.

La imagen `hive-cliente` es también la única que **fija `commons-cli` 1.6.0**
(sustituye el JAR 1.9.0 que trae Hadoop 3.5.0). Es el ajuste acotado que hace
funcionar a Sqoop 1.4.7 sin tocar los demonios ni Pig/Hive; el porqué está en
`docs/compatibilidad.md` §7. La imagen base `jgarciafl/hadoop` conserva la 1.9.0.

## 2. Servicios, roles y perfiles

El rol de cada contenedor se define con la variable `ROLE` y la despacha
`hadoop/scripts/entrypoint.sh`. Los servicios se agrupan en **perfiles** de
Compose para poder arrancar solo lo necesario (requisito de 16 GB de RAM):

| Servicio | `ROLE` | Procesos | Imagen | Perfil |
|---|---|---|---|---|
| `namenode` | `namenode` | NameNode + receptor Flume (`avro:4141 → HDFS`) | `jgarciafl/hive-cliente` | **ligero** (siempre) |
| `yarnmaster` | `resourcemanager` | ResourceManager + ProxyServer + JobHistory Server | `jgarciafl/yarnmaster` | **ligero** (siempre) |
| `jupyter` | `jupyter` | Jupyter Notebook (8889, sin token por defecto) | `jgarciafl/jupyter` | **ligero** (siempre) |
| `datanode1` | `datanode` | DataNode (HDFS) **y** NodeManager (YARN) | `jgarciafl/hadoop` | **ligero** (por defecto) |
| `datanode2` | `datanode` | DataNode + NodeManager | `jgarciafl/hadoop` | `dn2` |
| `datanode3` | `datanode` | DataNode + NodeManager | `jgarciafl/hadoop` | `dn3` |
| `hive-metastore-db` | – | MySQL 8 (esquema del metastore) | `mysql:8.0` | `full` |
| `hive-server` | `hive-server` | Hive Metastore (9083) + HiveServer2 (10002) | `jgarciafl/hive-cliente` | `full` |
| `flume-agent` | `flume-agent` | Agente Flume `agente1` (`spooldir → avro`) | `jgarciafl/flume-agent` | `full` |

* **Modo ligero (por defecto)**: `namenode`, `yarnmaster`, `jupyter`,
  `datanode1`. Cubre HDFS, YARN/MapReduce, Pig, Python y notebooks.
* **Perfil `full`**: añade Hive (con su MySQL) y el agente Flume. Se activa con
  `scripts/up.* -Full` (`--profile full`).
* **Perfiles `dn2` / `dn3`**: añaden el 2.º y 3.ᵉʳ DataNode. Se activan con
  `scripts/up.* -DataNodes 2|3` o `scripts/datanodes.*`.

> `--profile` es un flag **global** de Compose: va **antes** del subcomando
> (`docker compose --profile full up -d`). Un `up` sin perfiles **no** detiene
> los contenedores ya arrancados con un perfil; para bajar de 3 a 1 DataNode se
> usa `docker compose rm -sf datanodeN`, que conserva el volumen.

### Decisiones respecto a la estructura propuesta en el encargo

1. **`namenode` y `hive-server` son servicios separados** (aunque comparten
   imagen): cada uno es un maestro distinto (HDFS y Hive) con su propio ciclo
   de vida, su healthcheck y su volumen. Así se reinicia Hive sin tocar el
   NameNode (pruebas E4 y K3 lo acreditan).
2. **`hive-metastore-db` es MySQL en contenedor propio** con volumen
   `mysql-data`, en lugar del `mysql-server` embebido en el contenedor del
   NameNode que tenía el proyecto original: separa datos de servicios y evita
   que el arranque de MySQL dependa de `HOSTNAME=namenode`.
3. **`datanode` y `nodemanager` están co-localizados** (como en la arquitectura
   original): al escalar almacenamiento se escala también capacidad de cálculo,
   y se ahorra un JVM por nodo. El script `start-nodemanager.sh` existe por si
   se necesita un nodo de cómputo aislado.
4. **Se conserva el agente Flume original** (`agente.conf`: `spooldir → avro →
   namenode:4141`). El repositorio no traía el receptor, por eso se añade
   `receiver.conf` en la imagen del NameNode; la cadena queda completa y es
   verificable en HDFS.
5. **Jupyter pasa a contenedor propio.** En el modo local arranca **sin token**
   (cómodo para el alumnado) pero **publicado solo en `127.0.0.1`**; el perfil
   remoto exige token (`JUPYTER_TOKEN` no vacío). Nunca se versionan secretos.

## 3. Red y nombres DNS

* Red única `bigdata-hadoop` (puente). Los nombres de servicio de Compose
  (`namenode`, `yarnmaster`, `hive-server`, `hive-metastore-db`, …) se usan
  como nombres DNS internos en toda la configuración:
  * `fs.defaultFS = hdfs://namenode:8020`
  * `yarn.resourcemanager.hostname = yarnmaster`
  * `mapreduce.jobhistory.* = yarnmaster:10020 / 19888`
  * `javax.jdo.option.ConnectionURL = jdbc:mysql://hive-metastore-db:3306/...`
  * `hive.metastore.uris = thrift://hive-server:9083`
  * Flume: `sink1.hostname = namenode`
* **No hay `localhost` como dirección de otro servicio.**
* Las pruebas de integración usan esta misma resolución DNS para decidir si un
  servicio avanzado está activo (un contenedor no creado **no** resuelve).

## 4. Volúmenes

| Volumen | Montaje | Servicio | Persistencia |
|---|---|---|---|
| `namenode-data` | `/hdfs/namenode` | `namenode` | metadatos de HDFS (VERSION, edits, fsimage) |
| `datanode1-data` … `datanode3-data` | `/hdfs/datanode` | `datanode1..3` | bloques de datos (uno por nodo) |
| `mysql-data` | `/var/lib/mysql` | `hive-metastore-db` | esquema y metadatos de Hive |
| bind `./notebooks` | `/media/notebooks` | `jupyter` | cuadernos (recurso del usuario) |
| bind `./namenode-cliente/dataset` (ro) | `/dataset` | `jupyter` | datasets de prácticas (`texto.txt`, `quijote.txt`) |
| bind `./tests` (ro) | `/tests` | `namenode`, `jupyter` | suite de pruebas y muestras |
| bind `./hadoop/hadoopconf` (ro) | `/app/hadoop-3.5.0/etc/hadoop` | `namenode`, `hive-server`, `yarnmaster`, `datanode*` | configuración editable sin reconstruir imágenes. **Atención:** al montar el directorio completo, los ficheros por defecto de la distribución (`capacity-scheduler.xml`, `log4j.properties`) deben estar **también** en el repositorio, si no desaparecen (ver `docs/compatibilidad.md` §13) |
| bind `./spooldir` | `/spooldir` | `namenode`, `flume-agent` | entrada de Flume desde el host |

**Cada DataNode tiene su propio volumen.** Varios DataNodes montando el mismo
directorio se consideran el mismo nodo y el segundo no puede registrarse. Por
eso no se usa `docker compose up --scale`: además de no permitir un volumen
persistente con nombre por réplica, las réplicas escaladas reciben como
hostname el **ID del contenedor**, que cambia al recrearlas.

## 5. Puertos publicados

Todos se publican por defecto **solo en `127.0.0.1`**; la variable `BIND_ADDR`
en `.env` permite ampliarlo a la red del aula conscientemente.

| Puerto | Servicio | Interfaz |
|---|---|---|
| 9870 | NameNode Web UI | `127.0.0.1` (`BIND_ADDR`) |
| 8088 | ResourceManager Web UI | `127.0.0.1` (`BIND_ADDR`) |
| 19888 | JobHistory Web UI | `127.0.0.1` (`BIND_ADDR`) |
| 10002 | HiveServer2 (Beeline/JDBC, perfil `full`) | `127.0.0.1` (`BIND_ADDR`) |
| 8889 | Jupyter (sin token en local) | `127.0.0.1` (`BIND_ADDR`) |
| interno 8020/9866/9864/9083/10003/4141/10020/8089 | HDFS RPC/datanodes, metastore, HS2 web UI, Flume, history RPC, YARN ProxyServer | red interna |

## 6. Orden de arranque y healthchecks

```
[hive-metastore-db] ─(healthy)─► [hive-server] ─(10002)─┐   (perfil full)
[namenode] ─(9870 healthy)─► [datanode1..3]             │
     │                 └──► [yarnmaster] (8088)         │
     │                 └──► [flume-agent]               │   (perfil full)
     └──────────────────────────────► [jupyter] ◄───────┘
```

En el **modo ligero** solo existen `namenode`, `yarnmaster`, `datanode1` y
`jupyter`; `jupyter` no depende de `hive-server` (por eso el modo ligero no
arrastra Hive).

* `namenode`: espera a que el RPC 8020 y la UI 9870 respondan, sale del modo
  seguro y crea los directorios base (`/tmp`, `/user/root`, `/user/hive/warehouse`,
  `/flume/events`, `/mr-history`) de forma idempotente.
* `hive-server`: espera a que MySQL responda **y** autentique, **crea el esquema
  solo si no existe** (o lo **actualiza** con `schematool -upgradeSchema` si es
  de otra versión de Hive, sin borrar datos), y arranca Metastore antes que
  HiveServer2.
* `datanode*`: healthcheck contra la Web UI del DataNode (9864).
* `yarnmaster`: healthcheck contra `/ws/v1/cluster/info` (estado `STARTED`),
  y espera al JobHistory (`10020`/`19888`).
* `flume-agent`: comprueba que el proceso del agente `agente1` sigue vivo
  (no basta con que el contenedor esté `running`).
* `jupyter`: `GET /` (sin token responde 200/302).
* Políticas `restart: unless-stopped` y límites `mem_limit` en todos los
  servicios. Los NodeManagers declaran `yarn.nodemanager.resource.memory-mb=2048`
  (recursos *ofrecidos* al scheduler) y el contenedor DataNode+NodeManager tiene
  `mem_limit: 3g`. La memoria ofrecida se bajó a **2048 MB** (era 3072) para
  ajustarse al objetivo de 16 GB con 1–3 DataNodes.

## 7. Escalado de DataNodes (1 → 2 → 3)

`docker compose` en modo convencional **no** interpreta `deploy.replicas`
(fuera de Swarm solo es una opción orientada a despliegue), y una réplica
escalada no puede tener `container_name` ni un volumen propio determinista.
Por eso:

* Los DataNodes se definen en **`docker-compose.datanodes.yml`** usando un
  *anchor* YAML (`x-datanode`) para no repetir configuración:
  * `datanode1` → por defecto;
  * `datanode2` → `profiles: [dn2]`;
  * `datanode3` → `profiles: [dn3]`.
  Cada uno con su volumen `datanodeN-data`.
* Para escalar:

  ```powershell
  .\scripts\datanodes.ps1 -Count 3        # Windows
  ./scripts/datanodes.sh 3                # Linux/macOS
  ```

  y se comprueba con `hdfs dfsadmin -report | grep "Live datanodes"` (pruebas
  K5–K8). Para bajar de nuevo a 1: `.\scripts\datanodes.ps1 -Count 1`.
* **Registro de un DataNode nuevo**: se registra en segundos, pero el NameNode
  tarda en actualizar la lista de *vivos* al **reducir** (espera ~10,5 min a que
  expire el *heartbeat* del nodo retirado). El recuento exacto se obtiene
  reiniciando el NameNode (`docker compose restart namenode`), que **no** pierde
  datos.
* Con 1 DataNode, `dfs.replication = 1`. La distribución real de bloques entre
  varios nodos se practica con `hdfs dfs -setrep -w 2 <fichero>`.

## 8. Inicialización y persistencia (nunca destructiva)

* La imagen **no** formatea HDFS ni toca el metastore durante `docker build`.
* El contenedor del NameNode formatea **solo** si `/hdfs/namenode` está vacío;
  si ya existe `current/VERSION` no hace nada; si hay datos sin `VERSION`
  **aborta con mensaje de diagnóstico** en lugar de borrar.
* El metastore de Hive se inicializa con `schematool` únicamente cuando
  `schematool -info` indica que no hay esquema.
* `scripts/down.*` **no** usa `-v`: elimina contenedores y red pero **conserva**
  todos los volúmenes. Los datos sobreviven a `down` + `up`.
* Al arrancar **en frío**, el NameNode entra en **modo seguro** y *rechaza*
  escrituras hasta que los DataNodes envían su informe de bloques. La suite de
  integración espera a `Safe mode is OFF` antes de las pruebas de HDFS/YARN/Pig
  (de lo contrario `mkdir`/`put` fallarían de forma espuria). El estado se
  consulta con `hdfs dfsadmin -safemode get`.
* Si se reutiliza un volumen `namenode-data` de una topología anterior con más
  DataNodes y `dfs.replication=2`, los bloques cuyas réplicas estaban en nodos
  que ya no arrancan pueden quedar **sin ninguna réplica**; el NameNode se queda
  **atascado en modo seguro** y hay que arrancar esos DataNodes o reiniciar los
  datos de prácticas con `scripts/reset.*`. Ver README «Limitaciones conocidas».
* Para reinicializar deliberadamente (borra todos los datos): `scripts/reset.*`
  (pide escribir `BORRAR`).
