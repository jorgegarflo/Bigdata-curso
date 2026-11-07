# Matriz de compatibilidad de versiones

> Documento vivo. Las decisiones se justifican con **fuentes oficiales**
> consultadas y con **pruebas empíricas** ejecutadas en este repositorio
> (`tests/run-all.ps1` y `tests/integration.sh`), señalando expresamente qué
> está documentado y qué sólo está verificado en este entorno.

Fecha de las consultas: 19/10/2026.

## 1. Matriz de decisiones

| Componente | Versión actual | Versión elegida | Estado |
|---|---|---|---|
| Ubuntu | 20.04 | **24.04 LTS** (`ubuntu:24.04`) | Documentado + probado |
| Java | OpenJDK 8 | **OpenJDK 17** (`openjdk-17-jdk-headless`) | Documentado + probado |
| Hadoop | 3.3.1 (rutas rotas) | **3.5.0** | Documentado + probado |
| Hive | 3.1.2 | **4.1.0** (ver §4) | Documentado + probado |
| Pig | 0.17.0 | **0.18.0** | Documentado + probado |
| Flume | 1.9.0 | **1.11.0** | Documentado + probado |
| Sqoop | 1.4.7 | **1.4.7** + `commons-cli` **1.6.0** fijado (ver §7) | Documentado + probado |
| MySQL | mysql-server del SO | **`mysql:8.0`** (contenedor dedicado) | Documentado + probado |
| Jupyter | paquete apt de Ubuntu 20.04 | **`notebook` 7.x por pip** (venv) | Documentado + probado |
| spaCy | (no existía) | **3.7.5** + modelo **`es_core_news_sm` 3.7.0** (ver §10) | Documentado + probado |
| mrjob | `pip install mrjob` | **`mrjob` (última versión de pip, runner `hadoop`)** | Probado |
| Avro (Python) | `avro-python3` | **`avro`** (sucesor oficial mantenido) | Documentado + probado |

## 2. Hadoop 3.5.0 y Java

* Apache Hadoop **3.5.0** es una versión real publicada el **2 de abril de 2026**
  (primera estable de la rama 3.5, 485 correcciones/mejoras desde 3.4).
  Fuente: <https://hadoop.apache.org/releases.html> y
  <https://hadoop.apache.org/release/3.5.0.html>
* Requisito de Java (wiki oficial de versiones de Java de Hadoop, actualizado
  el 5 de mayo de 2026):

  > *"Apache Hadoop 3.5 and above: server side requires JDK17, client side
  > supports JDK17 and JDK21."*

  Fuente: <https://cwiki.apache.org/confluence/display/HADOOP/Hadoop+Java+Versions>

**Decisión:** OpenJDK **17** en todas las imágenes. Java 8/11 no es válido para
el lado servidor de Hadoop 3.5.0; Java 21 queda fuera del alcance (sólo
soportado en cliente).

## 3. Base del sistema operativo

* **Ubuntu 24.04 LTS**: mantiene `openjdk-17-jdk-headless`, `python3` (3.12),
  `mysql-client`, actualizaciones de seguridad activas y `multiarch` de
  paquetes. Ubuntu 20.04 llegó a fin de soporte estándar (abril/2025) y su JDK 17
  sólo se conseguía por backports; 20.04 se descarta por seguridad/mantenimiento.
* Todas las imágenes derivan de **una única imagen base** (`jgarciafl/hadoop:3.5.0`)
  para evitar descargas duplicadas de Hadoop y versiones de librerías distintas.

## 4. Hive (decisión más delicada)

Hive **3.1.2** fue la primera elección de la matriz del enunciado, pero
**Hive 3.1.x no puede arrancar HiveServer2 en Java 17**. Esto no es una
suposición: se comprobó empíricamente y coincide con el código fuente.

### 4.1 Por qué Hive 3.1.x es inviable con Java 17 (hallazgo verificado)

En Hive 3.1.3, `SessionState` hace un *cast* explícito del classloader a
`URLClassLoader`:

```java
parentLoader = SessionState.class.getClassLoader();
final ClassLoader currentLoader =
    Utilities.createUDFClassLoader((URLClassLoader) parentLoader, new String[]{});
```

Fuente: <https://github.com/apache/hive/blob/rel/release-3.1.3/ql/src/java/org/apache/hadoop/hive/ql/session/SessionState.java>

Desde Java 9 el classloader de la aplicación es un
`jdk.internal.loader.ClassLoaders$AppClassLoader` y **ya no es un
`URLClassLoader`**, así que ese *cast* lanza `ClassCastException` en la
construcción de cada sesión. HiveServer2 entra en un bucle de reintentos:

```
ERROR [main] server.HiveServer2: Error starting HiveServer2 on attempt 4, will retry in 60000ms
java.lang.RuntimeException: Error applying authorization policy on hive configuration:
  class jdk.internal.loader.ClassLoaders$AppClassLoader cannot be cast to class java.net.URLClassLoader
```

(Traza real obtenida en este entorno; se reproduce el patrón de errores del
hito HIVE-21301.) Nada de esto se puede arreglar por configuración: es código
compilado.

### 4.2 Comparación de ramas 4.x con `pom.xml` de cada tag

| Rama | `maven.compiler.source`/`target` (pom.xml del tag) | `SessionState` cast a `URLClassLoader` | ¿Runnable en Java 17? |
|---|---|---|---|
| 4.0.1 | `1.8` | Sí (presente, línea 477) | No (mismo `ClassCastException`) |
| **4.1.0** | **`17`** | **No (0 coincidencias)** | **Sí** |
| 4.2.0 / 4.2.1 | `21` | No | No (requiere Java 21) |

Fuentes: `pom.xml` y `SessionState.java` de cada tag en
<https://github.com/apache/hive> (`rel/release-4.0.1`, `rel/release-4.1.0`,
`rel/release-4.2.1`), consultados el 19/10/2026.

### 4.3 Decisión adoptada

**Hive 4.1.0** es la única rama que compila para Java 17 y no contiene el
*cast* incompatible. Además:

* Hadoop 3.5.0 exige Java 17 en servidor (ver §2), y Hive 4.1.0 está construido
  contra Hadoop **3.4.1** (`<hadoop.version>` en su `pom.xml`), lo que lo hace
  coherente con Hadoop 3.5.0; Hive 3.1.x estaba construido contra Hadoop 3.1.
* **Disponibilidad**: Hive 4.2.x ocupa el portada de
  <https://dlcdn.apache.org/hive/> (solo publica las versiones vigentes), y
  **4.1.0 sólo está en el archivo histórico**
  <https://archive.apache.org/dist/hive/hive-4.1.0/>. Por eso el Dockerfile
  fija `HIVE_MIRROR=https://archive.apache.org/dist` y **verifica el SHA-256
  oficial** (`apache-hive-4.1.0-bin.tar.gz.sha256`, 469 MB). Para no repetir esa
  descarga (~27 min a ~290 KB/s, único mirror accesible), el build acepta
  `namenode-cliente/cache/apache-hive-4.1.0-bin.tar.gz` ya descargado, **pero
  la verificación del checksum se hace igualmente**.

Impacto sobre las prácticas del curso (verificado en el repositorio):

* La prueba E ya usaba **Beeline** contra HiveServer2 (`jdbc:hive2://hive-server:10002`),
  así que la eliminación del antiguo CLI local de Hive en la rama 4 (HIVE-18485:
  `bin/hive` redirige a Beeline, `USE_BEELINE_FOR_HIVE_CLI="true"`) **no afecta**.
* Se fija explícitamente `hive.execution.engine=mr` para ejecutar sobre YARN
  (este entorno no distribuye Tez).
* El motor de arranque (`start-hive.sh`) gestiona ahora el esquema de forma
  versionada: crea, conserva o **actualiza** (`schematool -upgradeSchema`) sin
  borrar datos.
* `hcat_server.sh` (wrapper antiguo para arrancar el servidor de HCatalog, que
  además usaba `-XX:+UseConcMarkSweepGC`, retirado en Java 9+) se elimina: nadie
  lo invocaba, el metastore se arranca directamente y el CLI `hcat` sigue
  disponible en `${HCAT_HOME}/bin`.

### 4.4 Conflictos de librerías que siguen aplicándose en Hive 4.1.0

* Hive trae Guava **22.0** y Hadoop 3.5 trae una versión mayor: **se sustituye**
  la de `HIVE_HOME/lib` por la copia exacta de la de Hadoop (no se borra "para
  que no pite").
* Hive trae `log4j-slf4j-impl`, que duplica el binding SLF4J de Hadoop; se
  elimina el de Hive (binding único garantizado).
* Hive 4.1.0 sigue usando `commons-collections` **3.x** (`<commons-collections.version>3.2.2</commons-collections.version>`
  en su `pom.xml`) y Hadoop 3.5.0 ya no la distribuye (sólo `commons-collections4`);
  se aporta el JAR oficial con checksum (ver §12).

## 5. Pig

* Pig **0.17.0**: sus notas de release dicen literalmente *"This release is
  compatible with Hadoop 2.5+ releases"* y requiere Java 1.7+.
  Fuente: <https://archive.apache.org/dist/pig/pig-0.17.0/RELEASE_NOTES.txt>
  → **no es la combinación correcta para Hadoop 3.5.0**.
* Pig **0.18.0** (junio de 2025): *"Support for Hadoop 3, Tez 0.10, Spark 3,
  Hive 3 and HBase 2 and making them the default"*, *"Java 1.8.x or newer"*,
  y el binario `pig-0.18.0.tar.gz` es *"compatible with Hadoop 3"*.
  Fuente: <https://archive.apache.org/dist/pig/pig-0.18.0/RELEASE_NOTES.txt>

**Decisión:** **Pig 0.18.0** (binario Hadoop 3). Documentado como Hadoop-3;
**soporte en Java 17 no documentado** → se verifica con la prueba F
(`pig -x mapreduce` ejecutando un script real y comprobando el resultado).

## 6. Flume

* Flume **1.9.0** (2018) es antiguo para Java 17 (Guava 11, Log4j 1.x).
* Flume **1.11.0** es la última versión publicada (directorio en el mirror con
  fecha 2026-05-02) y está declarada *production-ready*, con actualización de
  dependencias (FLUME-3441: Scala 2.13.9, Gson 2.9.1, plugin Maven 3.2.2).
  Fuente: <https://flume.apache.org/releases/1.11.0.html>
  Binario oficial con `.sha512`:
  <https://archive.apache.org/dist/flume/1.11.0/>

**Decisión:** **Flume 1.11.0**. Se conservan `agente.conf` (fuente `spooldir`
→ `avro namenode:4141`) y los directorios de entrada del diseño original; se
añade el receptor que el repositorio no incluía (`namenode-cliente/flumeconf/receiver.conf`,
`avro:4141 → hdfs:/flume/events`) porque la cadena original estaba incompleta
(sólo existía el sumidero, no el sumidero receptor). Verificación con la
prueba G (fichero real en el spool → contenido comprobado en HDFS).

## 7. Sqoop (retirado, pero funcional fijando una dependencia)

* Sqoop se **retiró en junio de 2021** y pasó al Apache Attic en julio de 2021.
  Fuente: <https://attic.apache.org/projects/sqoop.html>
* Su único binario oficial, `sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz`, está
  construido **contra Hadoop 2.6.0** y trae sus propias copias de
  Hadoop/Java viejas. Fuente del binario:
  <https://archive.apache.org/dist/sqoop/1.4.7/>

### 7.1 ¿Es viable con Hadoop 3.5.0 + Java 17? Sí, con un ajuste acotado

Evaluado de forma **empírica** (no supuesta), apareció un único fallo de
arranque, reproducible:

```
ERROR org.apache.sqoop.cli.SqoopParser - Could not load required method of Parser:
java.lang.NoSuchMethodException: org.apache.commons.cli.Option.addValueForProcessing(java.lang.String)
```

Causa raíz: `SqoopParser` obtiene ese método **privado** por reflexión (ver el
`static {}` del descriptor de clase) y `commons-cli` lo **eliminó en la 1.7.0**.
Hadoop 3.5.0 distribuye **1.9.0**, donde ya no existe. Se comprobó con `javap`
contra las versiones publicadas en Maven Central que la **1.6.0 es la última
que conserva `addValueForProcessing` y a la vez ofrece `Option.builder`**
(presente desde la 1.3), la API que sí usa Hadoop. Los cambios de 1.7.0 en
adelante son aditivos/correctivos (verificados en las notas oficiales), por lo
que bajar a 1.6.0 no retira nada que Hadoop necesite.

### 7.2 Solución aplicada

En la **imagen cliente** (donde vive Sqoop) se **sustituye**
`${HADOOP_HOME}/share/hadoop/common/lib/commons-cli-1.9.0.jar` por **1.6.0**
(Maven Central, SHA-1 `38166a23afb5bd5520f739b87b3be87f7f0fb96d`, siempre
verificado en el build). Se descartó anteponer commons-cli al classpath de
Sqoop (`HADOOP_USER_CLASSPATH_FIRST`): eso pondría por delante las ~38 copias
antiguas de jackson/commons-io/commons-codec/... que trae Sqoop, tapando las de
Hadoop 3.5 (frágil y amplía el área de conflicto). Hive no se ve afectado
porque trae su **propia** copia (1.5.0) en `HIVE_HOME/lib`; Pig y los daemons de
Hadoop usan la 1.6.0 y siguen funcionando.

### 7.3 Resultado

Pruebas **H0–H4 PASADAS**: `sqoop import` (MySQL→HDFS) y `sqoop export`
(HDFS→MySQL) reales, con las 3 filas ida y vuelta.

Se conserva además, como **alternativa mantenible e independiente de Sqoop**,
`namenode-cliente/tools/sql_hdfs.py` (Python + `pymysql` + cliente `hdfs`), que
cubre el mismo objetivo didáctico "intercambio entre MySQL y HDFS" con las
mismas operaciones lógicas (`export tabla /ruta/hdfs` y `import /ruta/hdfs
tabla`) y que se valida en las pruebas H3/H4. Ventajas: 1 archivo y funciona con
Python 3.12 sin JVM. Inconvenientes: no replica la semántica de mappers,
`-m 1`, `--where`, `--as-avrofile` ni las tablas incrementales de Sqoop.
Alternativas descartadas por coste: Apache SeaTunnel y Apache Spark JDBC
(requieren otra distribución completa y ~500 MB extra).

## 8. MySQL

* Se usa la imagen oficial **`mysql:8.0`** (LTS) como contenedor
  `hive-metastore-db`, en lugar del servidor del SO dentro del contenedor del
  NameNode: separa datos (volumen `mysql-data`) de servicios, permite healthchecks
  y escalar/reiniciar Hive sin tocar el NameNode.
* Conector JDBC oficial **`mysql-connector-j` 8.0.33** desde Maven Central
  (verificado por SHA-1 publicado), compatible con MySQL 8 y Java 17.
  El repositorio original llevaba `mysql-connector-java-8.0.23.jar` versionado
  en git: se retira (un binario dentro del repositorio no es reproducible ni
  auditable) y se descarga con checksum en la construcción.

## 9. Python, mrjob y Avro

* **mrjob**: se instala la última versión de PyPI en un *venv* aislado
  (`/opt/bigdata/venv`, Python 3.12 de Ubuntu 24.04) y se ejecuta con el
  runner **`hadoop`** (Hadoop Streaming sobre YARN), no con `local`. La prueba
  I2 ejecuta un trabajo real y comprueba que la aplicación aparece en YARN.
* **avro-python3 está obsoleto**; el paquete oficial mantenido es **`avro`**
  (release 1.11+ en adelante, soporta Python 3.12). `tests/samples/avro_roundtrip.py`
  hace round-trip completo (escritura y lectura) para verificarlo.
* Los notebooks existentes no cambian de API: siguen siendo Python 3 y Jupyter.

## 10. Jupyter y spaCy

### 10.1 Jupyter

* El paquete `jupyter` de apt en Ubuntu 20.04 estaba desactualizado. Se instala
  **`notebook` 7.x** (Jupyter Notebook 7 / Jupyter Server) en el venv del
  sistema, versión fijada en el Dockerfile.
* **Seguridad:** por defecto el entorno es **local**, y Jupyter arranca **sin
  token ni contraseña** para que el alumnado abra el cuaderno sin copiar
  códigos. Esto es seguro porque el puerto se publica **solo en `127.0.0.1`**
  (variable `BIND_ADDR`; ninguna otra máquina puede alcanzarlo).
* **Perfil remoto (opcional):** si hay que exponer Jupyter (equipo remoto o
  aula), se define un `JUPYTER_TOKEN` no vacío en `.env` **y** `BIND_ADDR` en la
  IP/`0.0.0.0`. En cuanto `JUPYTER_TOKEN` tiene valor, el arranque activa la
  autenticación por token (sin él, 401/403). El original arrancaba siempre con
  token vacío y `--ip='*'`: se corrige porque exponer Jupyter sin autenticación
  en todas las interfaces permite ejecutar código arbitrario en el host.
  **Nunca** se versionan tokens.

### 10.2 spaCy y el modelo español

* Se instalan **`spacy==3.7.5`** y el modelo **`es_core_news_sm==3.7.0`** en la
  imagen de Jupyter (venv del sistema, Python 3.12 de Ubuntu 24.04). El modelo se
  obtiene de su *wheel* oficial y **queda dentro de la imagen**, de modo que los
  cuadernos funcionan **sin descargar nada en tiempo de ejecución**. Esto se
  comprueba en tiempo de build (import + `spacy.load` + lematización) y en la
  prueba J5 (dentro del kernel real de Jupyter).
* **Hallazgo: `import spacy` falla con `ModuleNotFoundError: No module named
  'click'`.** Causa raíz: spaCy 3.7.5 hace `from click import NoSuchOption` en
  `spacy/cli/_util.py`, pero **Typer ≥ 0.26 ha dejado de depender de `click`**
  (lo ha incorporado dentro de su propio código, *vendoring*). Como spaCy solo
  declaraba `typer` (y confiaba en que este trajese `click`), la instalación
  quedaba sin `click`. Fuente primaria: la documentación de Typer 0.27.3 en PyPI
  ("*Since version 0.26.0, Typer has vendored Click... instead of installing it
  as a third party package*").
  **Solución aplicada:** instalar `click` **explícitamente** en el Dockerfile
  (`click==8.1.8`). Con ella, el build de la imagen pasa y la prueba J5 confirma
  que spaCy carga el modelo y lematiza en español dentro del kernel.
* **Actualizaciones controladas:** para cambiar de versión se editan los `ARG`
  del Dockerfile (`SPACY_VERSION`, `SPACY_MODEL*`, `CLICK_VERSION`) y se
  reconstruye la imagen. **No** hay `pip install` en tiempo de ejecución.
* **Build sin red:** las dependencias **transitivas** de spaCy/Jupyter no están
  todas fijadas (solo `spacy`, `click`, `es_core_news_sm` y `notebook`); además
  el *wheel* del modelo se descarga de GitHub. Para construir en un equipo sin
  Internet se recomienda preparar un `pip download`/mirror interno con todas las
  dependencias resueltas. Queda como mejora pendiente.


## 11. Resumen de compatibilidad documentada vs. probada

| Par | Compatibilidad documentada | Verificación en este repositorio |
|---|---|---|
| Hadoop 3.5.0 + JDK 17 | Sí (wiki Hadoop) | Pruebas A2/C/D |
| Hive 4.1.0 + JDK 17 | **Sí** (compila con `maven.compiler.source=17` y no contiene el *cast* a `URLClassLoader`) | Pruebas A3, E, E4 (persistencia), K3 |
| Pig 0.18.0 + Hadoop 3 | Sí (release notes) | Prueba F |
| Pig 0.18.0 + JDK 17 | **No documentado** | Prueba F |
| Flume 1.11.0 + JDK 17 | No explícito (release actual, 2026) | Prueba G |
| Sqoop 1.4.7 + Hadoop 3.5 + JDK 17 | No documentado (retirado); **sí tras fijar `commons-cli` 1.6.0** | Pruebas H0–H4 |
| mrjob + Hadoop 3.5/YARN | Parcial | Prueba I2 |
| avro (Python) + Python 3.12 | Sí | Prueba I1 |
| spaCy 3.7.5 + Python 3.12 | Sí | Prueba J5 (kernel de Jupyter) |
| `es_core_news_sm` 3.7.0 + spaCy 3.7.5 | Sí (rango `<3.8.0,>=3.7.0`) | Pruebas J5/J7 (lematización real) |
| Typer ≥ 0.26 (sin `click`) + spaCy 3.7.5 | **No** (spaCy importa `click`) | Resuelto instalando `click` explícito; build + J5 (ver §10.2) |
| mysql-connector-j 8.0.33 + MySQL 8 + JDK 17 | Sí | Pruebas E/B6 |

## 12. Conflictos de librerías (Guava / SLF4J / Log4j / Jackson)

Regla aplicada: **nunca se borra un JAR para silenciar un error**; cada
modificación se documenta y es comprobable:

| Conflicto | Causa | Solución aplicada | Comprobación |
|---|---|---|---|
| Guava antiguo de Hive vs. Guava de Hadoop 3.5 | Hive distribuye Guava 22.0 (`<guava.version>` en su `pom.xml`); Hadoop 3.5.0 trae una versión mayor | Se **sustituye** la Guava de `HIVE_HOME/lib` por la de `HADOOP_HOME/share/hadoop/common/lib` | Pruebas A9 (classpath), E |
| `commons-collections` 3.x ausente en Hadoop 3.5 | `ObjectStore` de Hive usa `org.apache.commons.collections.CollectionUtils`; en Hadoop 3.3.1 venía en `share/hadoop/common/lib` y **Hadoop 3.5.0 sólo distribuye `commons-collections4`** (paquete `...collections4`, incompatible) | Se **añade** `commons-collections-3.2.2.jar` (Maven Central, SHA-1 verificado) a `HIVE_HOME/lib` y `SQOOP_HOME/lib`; no se borra `commons-collections4` de Hadoop | Arranque del Metastore (log `metastore.out` sin `ClassNotFoundException`) y pruebas E |
| `log4j-slf4j-impl` de Hive duplica el binding SLF4J de Hadoop | dos bindings SLF4J en el classpath | Se elimina el de Hive (se mantiene el de Hadoop) | Pruebas E1/E2 (sin `Multiple bindings` fatal) |
| Guava 11 de Flume 1.9 | Guava 11 muy antiguo | **No aplica:** Flume 1.11 ya no lleva esa copia; además Flume corre en proceso propio | Prueba G |
| Sqoop con copias propias de Hadoop 2.6 | proyecto retirado | No se parchea su Hadoop; se documenta (§7) | Pruebas H0–H4 |
| `commons-cli` sin `Option.addValueForProcessing` | `SqoopParser` (Sqoop 1.4.7) usa ese método privado por reflexión; `commons-cli` lo eliminó en la 1.7.0 y Hadoop 3.5.0 ya no trae 1.9.0 | Se **fija `commons-cli` 1.6.0** (última con `addValueForProcessing` **y** `Option.builder`) sustituyendo la copia de Hadoop **solo en la imagen cliente**; Hive conserva la suya (1.5.0) | Pruebas H0–H4 (import/export reales); A9/F/D sin regresión |

## 13. Hallazgos de arranque (3.5.0 real, fuera de la matriz)

Durante el levantamiento aparecieron dos problemas que la documentación de
Hadoop 3.5.0 no anticipa; ambos se resolvieron **por configuración** (sin
reconstruir imágenes y sin borrar componentes):

| Síntoma | Causa raíz | Solución |
|---|---|---|
| ResourceManager reiniciaba en bucle: `IllegalStateException: Queue configuration missing child queue names for root` | El bind-mount `./hadoop/hadoopconf → /app/hadoop-3.5.0/etc/hadoop` **ocultaba** los ficheros por defecto de la distribución, entre ellos `capacity-scheduler.xml` | Se copian `capacity-scheduler.xml` y `log4j.properties` (idénticos a los de la distribución 3.5.0) al directorio montado, de modo que siguen siendo editables sin rebuild |
| Tras "Arrancando ProxyServer..." el contenedor salía con código 1: `yarn.web-proxy.address is not set so the proxy will not run` | En Hadoop 3.5.0 `yarn.web-proxy.address` **no tiene valor por defecto** en `yarn-default.xml` (vacío); el daemon `proxyserver` lo exige explícito y termina con `-1`, y `set -e` tumba el script de arranque | Se define `yarn.web-proxy.address=yarnmaster:8089` + `yarn.web-proxy.bind-host=0.0.0.0` en `hadoop/hadoopconf/yarn-site.xml` |
| Metastore de Hive moría con `ClassNotFoundException: org.apache.commons.collections.CollectionUtils` | Ver fila de `commons-collections` en la tabla de la sección 12 | JAR añadido con checksum en el Dockerfile |
| El contenedor `yarnmaster` quedaba `unhealthy` aunque el RM respondía en `http://yarnmaster:8088`: el healthcheck (`curl localhost:8088`) devolvía `000` | `yarn.resourcemanager.hostname=yarnmaster` hace que la webapp se enlace **sólo a la IP que resuelve `yarnmaster`** (p. ej. `172.20.0.12:8088`) y no a `0.0.0.0`. Mismo motivo afectaba al JobHistory en 19888 | Se añaden `yarn.resourcemanager.bind-host=0.0.0.0`, `mapreduce.jobhistory.bind-host=0.0.0.0` y `mapreduce.jobhistory.rpc-bind-host=0.0.0.0` (sigue anunciándose `yarnmaster` a los NodeManagers). Verificado: `localhost:8088`, `localhost:19888` y `localhost:8089` devuelven 200/302 |
| `hive-server` nunca alcanzaba el estado `healthy` | HiveServer2 no podía crear ninguna sesión: `ClassCastException: jdk.internal.loader.ClassLoaders$AppClassLoader cannot be cast to java.net.URLClassLoader` en `SessionState` (ver §4.1); el puerto 10002 nunca se abría | Se cambia a **Hive 4.1.0** (única rama compilada para Java 17 sin ese *cast*) y se reconstruye la imagen `jgarciafl/hive-cliente:3.5.0` |
