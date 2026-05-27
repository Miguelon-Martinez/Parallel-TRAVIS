# Paralelización de análisis MATLAB por chunks

Este repositorio contiene un flujo de trabajo para procesar archivos `.dat` grandes dividiéndolos en varios chunks, analizándolos en paralelo con MATLAB y reconstruyendo después un único archivo final.

La idea es usar paralelización externa: en vez de usar `parfor` dentro de MATLAB, se lanzan varias instancias independientes de MATLAB mediante GNU Parallel. Cada instancia procesa un chunk distinto del archivo original.

---

## Estructura esperada

```text
.
├── run_parallel.sh
├── split_dat_chunks.m
├── merge_ana_chunks.m
├── SA_RunTravis_parallel.m
├── input/
│   └── archivo.dat
├── chunks/
├── output_chunks/
├── output/
└── logs/
```

### Directorios

- `input/`: contiene los archivos `.dat` originales.
- `chunks/`: contiene los chunks generados automáticamente a partir del input.
- `output_chunks/`: contiene los chunks ya analizados por MATLAB.
- `output/`: contiene el archivo final reconstruido.
- `logs/`: contiene logs de ejecución, incluyendo el `joblog` de GNU Parallel.

Los directorios `chunks/`, `output_chunks/` y `logs/` se pueden considerar temporales. El resultado final importante queda en `output/`.

---

## Workflow completo

El flujo completo es:

```text
input/archivo.dat
        |
        | split_dat_chunks.m
        v
chunks/archivo_c1.dat
chunks/archivo_c2.dat
chunks/archivo_c3.dat
...
        |
        | GNU Parallel + MATLAB + SA_RunTravis_parallel.m
        v
output_chunks/archivo_c1_ana.dat
output_chunks/archivo_c2_ana.dat
output_chunks/archivo_c3_ana.dat
...
        |
        | merge_ana_chunks.m
        v
output/archivo_ana.dat
```

Es decir:

1. Se parte el archivo original en varios chunks.
2. Cada chunk se procesa en paralelo con `SA_RunTravis_parallel.m`.
3. Los chunks analizados se guardan en `output_chunks/`.
4. Finalmente se juntan todos los chunks analizados en un único archivo final dentro de `output/`.

---

## Convención de nombres

Si el archivo original es:

```text
input/archivo.dat
```

entonces los chunks generados son:

```text
chunks/archivo_c1.dat
chunks/archivo_c2.dat
chunks/archivo_c3.dat
...
```

Después del análisis, se espera que `SA_RunTravis_parallel.m` genere:

```text
output_chunks/archivo_c1_ana.dat
output_chunks/archivo_c2_ana.dat
output_chunks/archivo_c3_ana.dat
...
```

El archivo final reconstruido será:

```text
output/archivo_ana.dat
```

---

## Requisitos

Para usar este flujo necesitas:

- MATLAB instalado y accesible desde terminal mediante el comando `matlab`.
- GNU Parallel instalado.
- Un entorno tipo Linux, WSL o servidor HPC.
- Los archivos `.m` necesarios en el mismo directorio de trabajo o accesibles desde el path de MATLAB:
  - `split_dat_chunks.m`
  - `merge_ana_chunks.m`
  - `SA_RunTravis_parallel.m`

En Ubuntu/WSL, GNU Parallel se puede instalar con:

```bash
sudo apt update
sudo apt install parallel
```

---

## Uso básico

Coloca el archivo que quieres analizar dentro de `input/`:

```text
input/archivo.dat
```

Da permisos de ejecución al script:

```bash
chmod +x run_parallel.sh
```

Ejecuta:

```bash
./run_parallel.sh archivo.dat
```

No hace falta escribir `input/archivo.dat`, porque el script asume que el archivo está dentro de `input/`.

---

## Variables principales del script

Dentro de `run_parallel.sh` se pueden modificar varias variables.

### Archivo de entrada

```bash
INPUT_FILE="input/$1"
```

El script toma como argumento solo el nombre del archivo. Por ejemplo:

```bash
./run_parallel.sh archivo.dat
```

se interpreta internamente como:

```text
input/archivo.dat
```

---

### Directorio de trabajo

```bash
WORKDIR="$(pwd)"
```

Indica que el directorio de trabajo es la carpeta actual desde la que se lanza el script.

Normalmente no hace falta cambiarlo.

---

### Número de procesos paralelos

```bash
N_JOBS=4
```

Controla cuántas instancias de MATLAB se ejecutan simultáneamente.

En este workflow, `N_JOBS` también se usa como número de chunks. Por ejemplo:

```bash
N_JOBS=32
```

significa:

```text
32 chunks
32 procesos MATLAB en paralelo
```

Como cada MATLAB se lanza con `-singleCompThread`, cada proceso usa aproximadamente un core. Por eso, en una máquina con 32 cores físicos, un valor razonable de partida es:

```bash
N_JOBS=32
```

Si el proceso consume demasiada RAM, licencias o I/O de disco, conviene bajar este valor, por ejemplo:

```bash
N_JOBS=16
```

---

### Número de líneas de cabecera

```bash
N_HEADER_LINES=0
```

Indica cuántas líneas iniciales del archivo son cabecera.

Si el `.dat` no tiene cabecera:

```bash
N_HEADER_LINES=0
```

Si tiene una línea de cabecera:

```bash
N_HEADER_LINES=1
```

Si tiene dos líneas de cabecera:

```bash
N_HEADER_LINES=2
```

Durante el split, la cabecera se copia a cada chunk. Durante el merge, se conserva la cabecera del primer chunk y se eliminan las cabeceras repetidas de los chunks siguientes.

---

### Directorios internos

```bash
CHUNKS_DIR="chunks"
OUTPUT_CHUNKS_DIR="output_chunks"
OUTPUT_DIR="output"
LOGS_DIR="logs"
FILES_LIST="logs/files.txt"
```

Estos valores indican dónde se guardan los archivos intermedios y finales.

- `CHUNKS_DIR`: chunks sin analizar.
- `OUTPUT_CHUNKS_DIR`: chunks ya analizados.
- `OUTPUT_DIR`: resultado final.
- `LOGS_DIR`: logs de ejecución.
- `FILES_LIST`: lista temporal de chunks que GNU Parallel debe procesar.

Normalmente no hace falta cambiar estas rutas.

---

## Qué hace `run_parallel.sh`

El script realiza los siguientes pasos:

### 1. Define el input

```bash
INPUT_FILE="input/$1"
```

Esto permite ejecutar:

```bash
./run_parallel.sh archivo.dat
```

sin tener que escribir:

```bash
./run_parallel.sh input/archivo.dat
```

---

### 2. Crea los directorios necesarios

```bash
mkdir -p "$CHUNKS_DIR" "$OUTPUT_CHUNKS_DIR" "$OUTPUT_DIR" "$LOGS_DIR"
```

Esto asegura que existan las carpetas necesarias antes de empezar.

---

### 3. Limpia archivos temporales antiguos

Antes de crear nuevos chunks, se eliminan chunks anteriores asociados al mismo input:

```bash
rm -f "$CHUNKS_DIR/${INPUT_STEM}"_c*"$INPUT_EXT"
rm -f "$OUTPUT_CHUNKS_DIR/${INPUT_STEM}"_c*_ana"$INPUT_EXT"
rm -f "$FILES_LIST"
```

Esto evita mezclar resultados viejos con una ejecución nueva.

Estas líneas no borran el archivo final:

```text
output/archivo_ana.dat
```

Solo borran archivos temporales de `chunks/`, `output_chunks/` y la lista `logs/files.txt`.

---

### 4. Parte el archivo en chunks

```bash
matlab -singleCompThread -nodisplay -nosplash -batch \
"split_dat_chunks('$INPUT_FILE','$WORKDIR',$N_HEADER_LINES,$N_JOBS)"
```

Esto llama a `split_dat_chunks.m` desde MATLAB.

El último argumento es `N_JOBS`, porque en este workflow el número de chunks se toma igual al número de procesos paralelos.

---

### 5. Genera la lista de chunks

```bash
find "$CHUNKS_DIR" -maxdepth 1 -name "${INPUT_STEM}_c*${INPUT_EXT}" | sort -V > "$FILES_LIST"
```

Esto crea una lista ordenada de chunks para GNU Parallel.

Se usa `sort -V` para ordenar correctamente nombres como:

```text
archivo_c1.dat
archivo_c2.dat
archivo_c10.dat
```

en vez de obtener un orden lexicográfico incorrecto como:

```text
archivo_c1.dat
archivo_c10.dat
archivo_c2.dat
```

---

### 6. Procesa los chunks en paralelo

```bash
parallel -j "$N_JOBS" --joblog "$LOGS_DIR/joblog.txt" \
'matlab -singleCompThread -nodisplay -nosplash -batch "SA_RunTravis_parallel('\''{}'\'')"' \
:::: "$FILES_LIST"
```

Esto lanza una instancia de MATLAB por chunk, hasta un máximo de `N_JOBS` procesos simultáneos.

Cada ejecución equivale a hacer en MATLAB:

```matlab
SA_RunTravis_parallel('chunks/archivo_c1.dat')
SA_RunTravis_parallel('chunks/archivo_c2.dat')
SA_RunTravis_parallel('chunks/archivo_c3.dat')
```

Cada llamada debe generar su correspondiente archivo analizado en `output_chunks/`.

---

### 7. Une los chunks analizados

```bash
matlab -singleCompThread -nodisplay -nosplash -batch \
"merge_ana_chunks('$INPUT_FILE','$OUTPUT_CHUNKS_DIR','$OUTPUT_DIR',$N_HEADER_LINES)"
```

Esto junta los archivos:

```text
output_chunks/archivo_c1_ana.dat
output_chunks/archivo_c2_ana.dat
output_chunks/archivo_c3_ana.dat
...
```

y crea:

```text
output/archivo_ana.dat
```

---

## Opciones de MATLAB utilizadas

Cada llamada a MATLAB usa:

```bash
-singleCompThread -nodisplay -nosplash -batch
```

### `-singleCompThread`

Hace que cada instancia de MATLAB use un solo thread interno.

Esto es importante porque ya estamos paralelizando por fuera con GNU Parallel. Si se lanzan 32 MATLAB y cada uno intenta usar todos los cores, el sistema se sobresatura.

### `-nodisplay`

Ejecuta MATLAB sin interfaz gráfica.

### `-nosplash`

Evita mostrar la pantalla inicial de MATLAB.

### `-batch`

Ejecuta el comando indicado y cierra MATLAB al terminar.

---

## Suposiciones importantes

Este workflow asume que:

1. Las filas del archivo `.dat` son independientes entre sí.
2. El resultado de analizar cada chunk por separado es equivalente a analizar el archivo completo y luego juntar los resultados.
3. `SA_RunTravis_parallel.m` puede ejecutarse directamente sobre un chunk.
4. `SA_RunTravis_parallel.m` genera un archivo `_ana.dat` por cada chunk.
5. Los chunks analizados se guardan en `output_chunks/`.
6. La convención de nombres es:

```text
chunks/archivo_c1.dat
output_chunks/archivo_c1_ana.dat
output/archivo_ana.dat
```

Si alguna de estas condiciones no se cumple, habrá que adaptar el script o las funciones MATLAB.

---

## Ejemplo completo

Supongamos que tienes:

```text
input/QMRV1_230323047.dat
```

Ejecutas:

```bash
./run_parallel.sh QMRV1_230323047.dat
```

Si `N_JOBS=4`, se generarán:

```text
chunks/QMRV1_230323047_c1.dat
chunks/QMRV1_230323047_c2.dat
chunks/QMRV1_230323047_c3.dat
chunks/QMRV1_230323047_c4.dat
```

Después del análisis:

```text
output_chunks/QMRV1_230323047_c1_ana.dat
output_chunks/QMRV1_230323047_c2_ana.dat
output_chunks/QMRV1_230323047_c3_ana.dat
output_chunks/QMRV1_230323047_c4_ana.dat
```

Finalmente:

```text
output/QMRV1_230323047_ana.dat
```

---

## Comprobación de errores

GNU Parallel genera un log en:

```text
logs/joblog.txt
```

Este archivo permite comprobar qué jobs se ejecutaron, cuánto tardaron y si alguno falló.

Para verlo:

```bash
cat logs/joblog.txt
```

Si algún chunk falla, conviene revisar:

1. Que MATLAB puede ejecutarse desde terminal.
2. Que `SA_RunTravis_parallel.m` está en el path de MATLAB.
3. Que el chunk correspondiente existe en `chunks/`.
4. Que `SA_RunTravis_parallel.m` escribe correctamente el resultado en `output_chunks/`.
5. Que el nombre del output sigue el patrón esperado: `archivo_c1_ana.dat`, `archivo_c2_ana.dat`, etc.

---

## Limpieza de temporales

Los archivos temporales principales son:

```text
chunks/archivo_c*.dat
output_chunks/archivo_c*_ana.dat
logs/files.txt
```

Se pueden borrar sin perder el resultado final, siempre que el merge ya haya terminado correctamente.

El archivo final está en:

```text
output/archivo_ana.dat
```

Ese archivo no debe borrarse si se quiere conservar el resultado.

---

## Notas sobre rendimiento

Si la máquina tiene 32 cores físicos y cada MATLAB se ejecuta con `-singleCompThread`, un buen punto de partida es:

```bash
N_JOBS=32
```

Sin embargo, el valor óptimo puede depender de:

- RAM disponible.
- Velocidad del disco.
- Licencias MATLAB disponibles.
- Coste real de `SA_RunTravis_parallel.m`.
- Tamaño del archivo `.dat`.

Si el sistema se satura, baja `N_JOBS`.

---

## Adaptar el workflow a otra función MATLAB

Si en vez de `SA_RunTravis_parallel.m` se quiere usar otra función, hay que cambiar esta parte de `run_parallel.sh`:

```bash
SA_RunTravis_parallel('{}')
```

por la función correspondiente. Por ejemplo:

```bash
mi_funcion('{}')
```

La función debe aceptar como argumento la ruta de un chunk `.dat`.

