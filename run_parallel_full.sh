#!/usr/bin/env bash

set -euo pipefail                                                               #     / -e : si el comando falla el script se para
                                                                                # <---| -u : si usas una variable no definida, el script se para
                                                                                #     \ -o pipefail : si falla algo dentro de un pipe el script lo detecta

# =========================
# Configuración
# =========================

INPUT_FILE="input/$1"                                          # Si pasas un argumento (./run_parallel_full.sh X ) se usa como input. No hace falta explicitar la ruta de /input.

WORKDIR="${WORKDIR:-$(pwd)}"                                   # Si existe la variable WORKDIR usala, si no usa el directorio actual. Esto es por si queremos mover el workspace de sitio.

N_JOBS="${N_JOBS:-4}"                                          # Por defecto, 4 paralelizaciones, y por ende tantos chunks como jobs (por defecto, se puede cambiar.).
N_CHUNKS="${N_CHUNKS:-$N_JOBS}"
N_HEADER_LINES="${N_HEADER_LINES:-1}"

CHUNKS_DIR="$WORKDIR/chunks"
OUTPUT_CHUNKS_DIR="$WORKDIR/output_chunks"
OUTPUT_DIR="$WORKDIR/output"
LOGS_DIR="$WORKDIR/logs"
FILES_LIST="$LOGS_DIR/files.txt"

MATLAB_BIN="${MATLAB_BIN:-matlab}"                             # Usa el Matlab por defecto del servidor. Puedes cambiarlo flow : MATLAB_BIN=/usr/local/MATLAB/R2024b/bin/matlab ./run_parallel_full.sh input/archivo.dat

# =========================
# Preparación
# =========================

mkdir -p "$CHUNKS_DIR" "$OUTPUT_CHUNKS_DIR" "$OUTPUT_DIR" "$LOGS_DIR"       ## Creación de directorios en caso de que no existan.

INPUT_FILE_ABS="$(realpath "$INPUT_FILE")"                                  ## Paso a rutas absolutas input/archivo.dat --> /Users/u7733/.../input/archivo.dat
WORKDIR_ABS="$(realpath "$WORKDIR")"

INPUT_BASENAME="$(basename "$INPUT_FILE_ABS")"
INPUT_STEM="${INPUT_BASENAME%.*}"                                           ## INPUT_BASENAME : QMVR1_230323047.dat // INPUT_STEM : QMRV1_230323047 // INPUT_EXT : .dat
INPUT_EXT=".${INPUT_BASENAME##*.}"

echo "Input file       : $INPUT_FILE_ABS"                                   # /     
echo "Workdir          : $WORKDIR_ABS"                                      # |    
echo "N_CHUNKS         : $N_CHUNKS"                                         # |     INFORMACIÓN SOBRE EL SCRIPT PARA VER CUANDO ESTÁ CORRIENDO.
echo "N_JOBS           : $N_JOBS"                                           # |    
echo "N_HEADER_LINES   : $N_HEADER_LINES"                                   # |
echo                                                                        # \

# Opcional: limpiar resultados anteriores de este input
rm -f "$CHUNKS_DIR/${INPUT_STEM}"_c*"$INPUT_EXT"
rm -f "$OUTPUT_CHUNKS_DIR/${INPUT_STEM}"_c*_ana"$INPUT_EXT"
rm -f "$FILES_LIST"

# =========================
# 1. Split
# =========================

echo "=== Splitting input into chunks ==="

"$MATLAB_BIN" -singleCompThread -nodisplay -nosplash -batch \                       
"split_dat_chunks('$INPUT_FILE_ABS','$WORKDIR_ABS',$N_HEADER_LINES,$N_CHUNKS)"

# =========================
# 2. Crear lista ordenada de chunks
# =========================

find "$CHUNKS_DIR" -maxdepth 1 -name "${INPUT_STEM}_c*${INPUT_EXT}" | sort -V > "$FILES_LIST"

N_FOUND="$(wc -l < "$FILES_LIST")"                                              # /
                                                                                # |
if [ "$N_FOUND" -eq 0 ]; then                                                   # |
    echo "ERROR: No se encontraron chunks en $CHUNKS_DIR"                       # |
    exit 1                                                                      # | Información para DEBUG
fi                                                                              # |
                                                                                # |
echo "Chunks encontrados: $N_FOUND"                                             # |
cat "$FILES_LIST"                                                               # |
echo                                                                            # \

# =========================
# 3. Ejecutar SA_RunTravis_parallel en paralelo
# =========================

echo "=== Running MATLAB in parallel ==="

parallel -j "$N_JOBS" \                 ## lanza N_jobs
    --joblog "$LOGS_DIR/joblog.txt" \
    --halt soon,fail=1 \                ## Si falla un job deja de mandar trabajos
    "$MATLAB_BIN" -singleCompThread -nodisplay -nosplash -batch \
    "SA_RunTravis_parallel('{}')" \
    :::: "$FILES_LIST"

# =========================
# 4. Merge
# =========================

echo
echo "=== Merging analyzed chunks ==="

"$MATLAB_BIN" -singleCompThread -nodisplay -nosplash -batch \
"merge_ana_chunks('$INPUT_FILE_ABS','$OUTPUT_CHUNKS_DIR','$OUTPUT_DIR',$N_HEADER_LINES)"

echo
echo "Pipeline finished."
echo "Output should be in: $OUTPUT_DIR/${INPUT_STEM}_ana${INPUT_EXT}"
