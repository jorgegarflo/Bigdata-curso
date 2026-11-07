# Entorno Big Data educativo — Hadoop 3.5.0 / Java 17

Plataforma Big Data didáctica en Docker Compose: HDFS, YARN/MapReduce, Hive,
Pig, Flume, Sqoop, Python (mrjob + Avro) y Jupyter Notebook (con **spaCy** y el
modelo español `es_core_news_sm` ya instalados).

El repositorio original estaba construido sobre Ubuntu 20.04 + Hadoop 3.3.1
(JDK 8) con rutas y versiones inconsistentes. Esta versión moderniza el
entorno a **Ubuntu 24.04 LTS + OpenJDK 17 + Apache Hadoop 3.5.0** y verifica
la compatibilidad de cada componente con pruebas funcionales reproducibles.

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/arquitectura.md`](docs/arquitectura.md) | Imágenes, servicios, perfiles, red, volúmenes, puertos, orden de arranque |
| [`docs/compatibilidad.md`](docs/compatibilidad.md) | Matriz de versiones, fuentes oficiales, conflictos de librerías |


## Requisitos y consumo de recursos

* Docker Engine 24+ con Compose v2 (`docker compose`).
* Windows 10/11 con Docker Desktop (backend WSL2) **o** Linux con Docker Engine.
* **16 GB de RAM en el equipo anfitrión** (objetivo de diseño del modo ligero).
  El entorno **ligero por defecto** (Jupyter + HDFS + YARN) deja margen amplio
  para el sistema, el navegador y el IDE.
* ~10 GB de disco para imágenes, volúmenes y datos de prácticas.

La configuración se organiza en **perfiles** para no arrancar más de lo
necesario:

| Perfil | Servicios | RAM medida (`docker stats`) | Cuándo usarlo |
|---|---|---|---|
| ligero (por defecto) | `namenode`, `yarnmaster`, `jupyter`, `datanode1` | **≈ 1,6 GB** | Prácticas de HDFS/YARN/MapReduce y notebooks |
| ligero con 3 DataNodes | + `datanode2`, `datanode3` | **≈ 2,4 GB** | Prácticas de distribución HDFS (replicación) |
| `--profile full` | + `hive-metastore-db`, `hive-server`, `flume-agent` | **≈ 3,1 GB** | Prácticas de Hive, Flume y Sqoop/MySQL |
| `--profile dn2` / `dn3` | + `datanode2` / `datanode3` | **≈ +0,44 GB por DataNode** | Escalado de HDFS (1→3 DataNodes) |

Estos valores son la **suma del uso observado** (conjunto de trabajo) de los
contenedores de este proyecto, medidos con `docker stats --no-stream`. No son
los *límites* configurados (`mem_limit`), que son mucho más holgados (2–3 GB por
contenedor) y existen solo como tope de seguridad.

Cómo medir el consumo real (no se usan estimaciones):

```bash
docker stats --no-stream            # uso observado por contenedor
./scripts/status.sh                 # Windows: .\scripts\status.ps1
```

## Puesta en marcha rápida

```bash
# 1. Configuración local (el .env SI se versiona al ser una Plataforma Big Data didáctica )
# cp .env.example .env          # Windows: Copy-Item .env.example .env
#    Rellena MYSQL_ROOT_PASSWORD y HIVE_DB_PASSWORD (solo hacen falta para
#    el perfil "full").  Para el modo ligero no hay que tocar nada más.

# 2. Construir y levantar el modo LIGERO (1 DataNode)
./scripts/up.sh               # Windows: .\scripts\up.ps1

# 3. Comprobar estado (contenedores, DataNodes vivos, YARN y memoria)
./scripts/status.sh           # Windows: .\scripts\status.ps1
```

En Windows/PowerShell los scripts gemelos son:

```powershell
.\scripts\build.ps1                     # construye las 5 imágenes locales
.\scripts\up.ps1                        # ligero (1 DataNode)
.\scripts\up.ps1 -Full                  # + Hive/MySQL/Flume
.\scripts\up.ps1 -DataNodes 3           # 3 DataNodes en modo ligero
.\scripts\datanodes.ps1 -Count 2        # escalar/quitar DataNodes en caliente
.\scripts\status.ps1                    # estado + memoria real
.\scripts\down.ps1                      # para y elimina contenedores CONSERVANDO volúmenes
.\scripts\reset.ps1                     # borrado deliberado de datos (pide confirmación)
```

Los `.sh` equivalentes (`scripts/*.sh`) permiten el mismo flujo en Linux/macOS.

Además, el repositorio ofrece scripts para el símbolo del sistema de Windows (`.bat`), que permite gestionar el entorno Docker Compose sin tener que ejecutar manualmente todos los comandos.

```cmd
.\scripts\build.bat
.\scripts\up.bat
.\scripts\up.bat -Full
.\scripts\up.bat -DataNodes 3
.\scripts\datanodes.bat -Count 2
.\scripts\datanodes.bat -Count 3 -Full
.\scripts\status.bat
.\scripts\down.bat
.\scripts\down.bat -Volumes
.\scripts\reset.bat
.\scripts\reset.bat -Yes
```
Los archivos `.bat` deben ejecutarse desde CMD o desde una terminal de Windows compatible. También pueden invocarse desde PowerShell, por ejemplo, mediante `.\scripts\status.bat`.

Precauciones:
- `down.bat` detiene y elimina los contenedores, pero conserva los volúmenes por defecto.
- `down.bat -Volumes` solicita escribir BORRAR antes de eliminar también los volúmenes.
- `reset.bat` elimina los datos persistentes y solicita confirmación. La opción `-Yes` omite esa confirmación.
- `datanodes.bat` permite ajustar el número de DataNodes sin reconstruir las imágenes, utilizando los argumentos que transmite a `up.bat`.
- `status.bat` muestra el estado de los contenedores, los DataNodes activos, los nodos YARN y el consumo observado de memoria y CPU.



#### Opciones de `up.bat`
```bat
scripts\up.bat
scripts\up.bat --DataNodes 2
scripts\up.bat --DataNodes 3
scripts\up.bat --Full
scripts\up.bat --Full --DataNodes 2
scripts\up.bat --Full --DataNodes 2
scripts\up.bat --WaitTimeout 1200
```


| Opción | Valor predeterminado | Descripción |
|---|---|---|
| `--DataNodes N` | `1` | Número de DataNodes. Valores admitidos: 1, 2 o 3. |
| `--Full` | Desactivado | Activa el perfil completo con Hive, MySQL y Flume. |
| `--WaitTimeout N` | `900` | Tiempo máximo de espera de Docker Compose, en segundos. |

Las opciones se pueden combinar. Por ejemplo:

```bat
scripts\up.bat --Full --DataNodes 2
```
Este comando levanta el perfil completo con dos DataNodes.

El script comprueba la existencia de `.env`, valida los parámetros, espera a que Docker Compose considere iniciados los servicios y muestra su estado final. Si se solicita un número menor de DataNodes que el utilizado anteriormente, elimina los contenedores sobrantes y conserva sus volúmenes.


## Servicios y accesos

Por defecto **todos los puertos se publican solo en `127.0.0.1`** (variable
`BIND_ADDR`), de modo que el entorno no queda expuesto a la red del aula.

| Servicio | URL / puerto | Contenedor | Perfil |
|---|---|---|---|
| NameNode Web UI | <http://127.0.0.1:9870> | `namenode` | ligero |
| ResourceManager | <http://127.0.0.1:8088> | `yarnmaster` | ligero |
| JobHistory Server | <http://127.0.0.1:19888> | `yarnmaster` | ligero |
| Jupyter Notebook | <http://127.0.0.1:8889> (**sin token**) | `jupyter` | ligero |
| HiveServer2 (Beeline/JDBC) | `jdbc:hive2://127.0.0.1:10002/default` | `hive-server` | `full` |
| Flume (avro, interno) | `namenode:4141` | `namenode` | ligero |
| DataNode Web UI (interno) | `datanodeN:9864` | `datanode1..3` | según `-DataNodes` |

Todos los servicios internos se comunican por **nombre DNS de Compose**
(`hdfs://namenode:8020`, `yarnmaster:8088`, `hive-server:10002`,
`hive-metastore-db:3306`); nunca se usa `localhost` entre contenedores.

### Jupyter sin token (perfil docente local)

En el modo ligero, Jupyter arranca **sin token y sin contraseña**: basta abrir
<http://127.0.0.1:8889> y empezar a trabajar, sin copiar códigos. Esto es
seguro porque el puerto se publica **solo en `127.0.0.1`**: no es accesible
desde otras máquinas de la red.

Si se necesita exponer Jupyter a la red (equipo remoto, aula), se usa el perfil
seguro: dejar `BIND_ADDR` en la IP o `0.0.0.0` **y** definir un `JUPYTER_TOKEN`
no vacío en `.env`. En cuanto `JUPYTER_TOKEN` tiene valor, el arranque activa la
autenticación por token (403/401 sin él). Nunca se guardan tokens en el repo.

> **Nunca** se usa `docker compose down -v` para parar el entorno: eso borraría
> los datos. `scripts/down.*` conserva siempre los volúmenes.


#### **Jupyter en español**
Si se desea poner Jupyter en español ejecute en una celda el siguiente comando:
```jupyter
!pip install jupyterlab-language-pack-es-ES
```
A continuación, cierre el navegador y vuélvalo abrir, en el menú `Settings > Language` seleccione `Español`. 

## Datasets y notebooks

* `notebooks/00_bienvenida.ipynb`: primer contacto (HDFS, Python, spaCy).
* `notebooks/01_quijote.ipynb`: práctica de conteo de palabras y NLP sobre
  *El Quijote* (descarga del texto, `collections.Counter`, tokenización y
  lematización con spaCy). Cada ejercicio plantea el objetivo y deja el código
  guiado; **las soluciones del profesorado van en una sección final separada**
  para no resolver la práctica al alumnado.
* `namenode-cliente/dataset/`: datos de trabajo. Incluye `texto.txt` y el
  *Quijote* (`quijote.txt`) como **respaldo sin conexión**: si el cuaderno no
  puede descargar el texto de Project Gutenberg, cae automáticamente en ese
  fichero. Los notebooks están montados en `/media/notebooks` y el dataset en
  `/dataset` (solo lectura).

## Estructura del repositorio

```
.
├── namenode-cliente/        # imagen Hive/Pig/Flume/Sqoop (namenode + hive-server)
│   ├── Dockerfile
│   ├── hiveconf/            # hive-site.xml (metastore en MySQL)
│   ├── flumeconf/           # receiver.conf (avro -> HDFS)
│   ├── scripts/             # start-hive.sh (idempotente), start-flume-receiver.sh
│   ├── cache/               # (opcional, ignorado en git) tarball de Hive pre-descargado
│   ├── dataset/             # datasets de prácticas (texto.txt, quijote.txt)
│   └── tools/sql_hdfs.py    # alternativa mantenible a Sqoop
├── notebooks/               # cuadernos de prácticas (00_bienvenida, 01_quijote)
├── spooldir/                # entrada de Flume desde el host
├── scripts/                 # up/down/reset/datanodes/status (.ps1, .bat y .sh)
├── docs/                    # arquitectura, compatibilidad y resultados
├── docker-compose.yml       # servicios maestros + perfil "full"
└── docker-compose.datanodes.yml  # datanode1 (defecto), dn2/dn3 (perfiles)
```

## Uso diario

```bash
# Abrir una shell en el cliente (Hadoop, Hive, Pig, Flume, Sqoop, Python)
docker compose exec namenode bash

# HDFS
hdfs dfs -ls /
hdfs dfs -put /dataset/texto.txt /user/root/

# MapReduce
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar \
  wordcount /dataset/texto.txt /tmp/wc

# Hive (perfil full)
beeline -u 'jdbc:hive2://hive-server:10002/default' -n root

# Pig (Hadoop 3 por defecto)
pig -x mapreduce -f /tests/samples/wordcount.pig

# Python / mrjob (runner hadoop => YARN real)
python3 /tests/samples/wordcount_mrjob.py -r hadoop \
  hdfs://namenode:8020/dataset/texto.txt -o hdfs://namenode:8020/tmp/wc-mrjob
```

## Escalado de DataNodes (1 → 2 → 3)

El entorno arranca con **un único DataNode** (adecuado para HDFS en un solo
equipo). Se puede escalar a 2 o 3 DataNodes sin perder datos:

```bash
./scripts/datanodes.sh 2            # Windows: .\scripts\datanodes.ps1 -Count 2
./scripts/datanodes.sh 3            # 3 DataNodes
./scripts/datanodes.sh 1            # vuelve a 1 (los datos se conservan)

# Equivalente, levantando desde cero:
./scripts/up.sh --datanodes 3       # Windows: .\scripts\up.ps1 -DataNodes 3
```

Cada DataNode es un **servicio con nombre propio y volumen propio**
(`datanodeN-data`), no una réplica escalada de un mismo servicio. El motivo
está documentado en `docker-compose.datanodes.yml`: `docker compose up --scale`
asigna a las réplicas un hostname igual al **ID del contenedor** (inestable al
recrear) y no permite dar **un volumen persistente con nombre propio a cada
réplica**; los volúmenes anónimos se perderían en un `down`/`up`. Con servicios
con nombre, el escalado es reversible y los bloques no se pierden.

Para ver cuántos DataNodes están vivos:

```bash
docker compose exec namenode hdfs dfsadmin -report | grep "Live datanodes"
./scripts/status.sh        # muestra el recuento y los nodos YARN
```

Nota: al reducir el número de DataNodes, el NameNode mantiene a los nodos
retirados como «vivos» hasta que caduca su *heartbeat* (~10,5 min). El recuento
exacto se obtiene al reiniciar el NameNode (`docker compose restart namenode`),
que no pierde datos.

Con 1 DataNode, `dfs.replication = 1` es lo correcto. Para practicar la
distribución de bloques entre varios nodos tras escalar:

```bash
hdfs dfs -setrep -w 2 /ruta/al/fichero
hdfs fsck /ruta/al/fichero -files -blocks -locations
```

## Seguridad

* `.env` **SI se versiona**; además se publica `.env.example` con valores a cambiar.
Ejemplo de fichero `env`:  
```env
# Direccion del host donde se publican los servicios web.
#   127.0.0.1 -> solo accesible desde esta maquina (recomendado / por defecto)
#   0.0.0.0   -> accesible desde la red del aula (usar con precaucion)
BIND_ADDR=127.0.0.1

# --- Base de datos del metastore de Hive (contenedor hive-metastore-db) -----
MYSQL_ROOT_PASSWORD=password
HIVE_DB_HOST=hive-metastore-db
HIVE_DB_PORT=3306
HIVE_DB_NAME=metastore
HIVE_DB_USER=hive
HIVE_DB_PASSWORD=password

# --- Jupyter Notebook --------------------------------------------------------
# PERFIL DOCENTE (por defecto): deja JUPYTER_TOKEN VACIO.  Jupyter se abre
# directamente en http://127.0.0.1:8889 (sin token ni contrasena), solo desde
# el navegador del propio anfitrion.
#
# PERFIL REMOTO (opcional): define un token para exigir autenticacion.  Usalo
# si vas a publicar Jupyter (BIND_ADDR=0.0.0.0) en un servidor accesible por
# otros equipos.
JUPYTER_TOKEN=
```
* Puertos publicados **solo en `127.0.0.1`** por defecto (`BIND_ADDR`); abrir a
  la red del aula es una decisión explícita (`BIND_ADDR=0.0.0.0` **+**
  `JUPYTER_TOKEN`).
* Jupyter en modo local **sin token** (cómodo para el alumnado); el perfil
  remoto exige token. En ningún caso se versionan secretos.
* No hay credenciales reales en el repositorio ni en las imágenes.

## Inicialización de datos (idempotente y no destructiva)

* **NameNode**: `start-namenode.sh` formatea **solo** si `/hdfs/namenode` está
  vacío. Si existe un NameNode válido no lo toca; si el directorio tiene datos
  desconocidos, se detiene con diagnóstico en vez de destruirlos.
* **Metastore**: `start-hive.sh` comprueba `schematool -info` e inicializa el
  esquema solo si no existe. Nunca reinicializa.
* **Parada normal** (`scripts/down.*`) **conserva** todos los volúmenes.
* **Reset deliberado**: `./scripts/reset.sh` (pide escribir `BORRAR`) elimina
  los volúmenes `namenode-data`, `datanode*-data` y `mysql-data`.

## Cambios respecto al repositorio original

| Original | Ahora | Motivo |
|---|---|---|
| Ubuntu 20.04 | Ubuntu 24.04 LTS | 20.04 sin soporte estándar; JDK 17 nativo |
| OpenJDK 8 | OpenJDK 17 | Hadoop 3.5 exige JDK 17 en servidor |
| Hadoop 3.3.1 con rutas 3.3.1/3.5.0 mezcladas | Hadoop 3.5.0, rutas coherentes | Versión fijada y verificada con checksum |
| `psroyano/*:v1` (imágenes externas) | 5 imágenes locales versionadas | Reproducibilidad y auditoría |
| Formateo de HDFS en `docker build` | Formateo controlado en el arranque | No se hornea estado en la imagen |
| MySQL embebido en el NameNode | Contenedor `mysql:8.0` + volumen | Aislamiento y persistencia |
| Jupyter sin token en el NameNode | Contenedor propio; token **opcional** | Comodidad local + seguridad en remoto |
| 4 DataNodes por defecto | **1 DataNode por defecto**, escalable a 3 | Ajuste a equipos de 16 GB |
| Flume sin receptor | `receiver.conf` (avro → HDFS) | La cadena original estaba incompleta |
| `deploy.replicas` para DataNodes | Servicios con nombre + perfiles `dn2`/`dn3` | `--scale` no da hostname/volumen por réplica |
| Pig 0.17.0 / Flume 1.9.0 | Pig 0.18.0 / Flume 1.11.0 | Compatibilidad con Hadoop 3 / Java 17 |
| Hive 3.1.2 (Java 8) | Hive **4.1.0** | Hive 3.1.x no arranca en Java 17 (`ClassCastException` del classloader); 4.1.0 es la rama compilada para Java 17 (4.2.x exige Java 21) |
| `avro-python3` | paquete `avro` | `avro-python3` está obsoleto |
| `mysql-connector-java-8.0.23.jar` versionado | descarga con checksum (8.0.33) | Nada de binarios opacos en git |

## Limitaciones conocidas

* **Sqoop 1.4.7** está retirado (Apache Attic) y su binario se construyó contra
  Hadoop 2.6. **Funciona** en este entorno fijando `commons-cli` **1.6.0**
  (Hadoop 3.5.0 distribuye la 1.9.0, que eliminó el método que `SqoopParser`
  usa por reflexión); ver `docs/compatibilidad.md` §7. Se valida con las
  pruebas H0–H4 (`sqoop import`/`export` reales) y se conserva la alternativa
  independiente `namenode-cliente/tools/sql_hdfs.py`.
* **Hive 3.1.x no es viable con Java 17** (HiveServer2 entra en bucle de
  `ClassCastException`). Se usa **Hive 4.1.0**, la última rama compilada para
  Java 17. El porqué y las fuentes están en `docs/compatibilidad.md` §4.
* **Pig 0.18.0** declara compatibilidad con Hadoop 3, pero no con Java 17; se
  verifica en la prueba F.
* **spaCy 3.7.5** importa el paquete `click`, pero **Typer ≥ 0.26 ya no depende
  de `click`** (lo ha incorporado internamente). Por eso el `Dockerfile` de
  Jupyter instala `click` **explícitamente**; si no, `import spacy` falla con
  `ModuleNotFoundError: No module named 'click'`. Ver `docs/compatibilidad.md` §10.
* Las dependencias **transitivas** de spaCy/Jupyter no están todas fijadas
  (solo `spacy`, `click`, `es_core_news_sm` y `notebook`). Para un build 100 %
  reproducible sin red se recomienda un `pip download`/mirror interno; ver
  `docs/compatibilidad.md` §10.
* Un único NameNode (sin HA) y un único ResourceManager: es un entorno
  didáctico, no de producción.
* Los DataNodes comparten host: la replicación HDFS protege frente a fallos de
  proceso, no frente a fallos de la máquina anfitriona.
* **Cambiar de topología reutilizando datos antiguos**: si vienes de la
  configuración anterior (4 DataNodes y `dfs.replication=2`) y reutilizas el
  volumen `namenode-data`, el NameNode puede quedar **atascado en modo seguro**:
  los bloques cuyas réplicas vivían en DataNodes que ya no se arrancan se quedan
  sin ninguna réplica (`hdfs fsck /` los lista como *missing*) y, con 1 DataNode,
  nunca se alcanza el umbral para salir del modo seguro. En ese estado HDFS
  **rechaza las escrituras** (`Name node is in safe mode`). Opciones: arrancar
  los DataNodes que contenían los datos, o —si son datos de prácticas
  desechables— reiniciar con `./scripts/reset.*` (destructivo). Ver «Solución de
  problemas».

## Solución de problemas

```bash
# Estado y salud
docker compose -f docker-compose.yml -f docker-compose.datanodes.yml ps
./scripts/status.sh                      # incluye DataNodes vivos y memoria

# Logs de un servicio
docker compose logs --tail=100 namenode

# Logs internos de Hadoop
docker compose exec namenode tail -n 100 /app/hadoop-3.5.0/logs/hadoop-root-namenode-namenode.log

# El NameNode no arranca y el volumen tiene datos raros
docker compose logs namenode             # verá el diagnóstico de start-namenode.sh

# HDFS rechaza escrituras con «Name node is in safe mode»
docker compose exec namenode hdfs dfsadmin -safemode get    # ¿ON?
docker compose exec namenode hdfs fsck / | tail -6          # bloques missing/under-replicated
# Si hay bloques sin réplicas (datos antiguos de otra topología) y no se
# necesitan: reiniciar de cero (BORRA datos, pide confirmación escribiendo BORRAR)
./scripts/reset.sh

# Empezar de cero (BORRA datos, pide confirmación escribiendo BORRAR)
./scripts/reset.sh
```
